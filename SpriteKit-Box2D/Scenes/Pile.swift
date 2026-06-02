/**
 
 # Pile Of Blocks
 
 Pile performance test.
 Increase the number of columns and rows in createBlocks, and run in release build.
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 19 May 2026
 
 */
import SwiftUI
import SpriteKit
import Box2D

// MARK: View

struct PileOfBlocksView: View {
    var body: some View {
        ZStack {
            SpriteView(
                scene: PileOfBlocksScene(),
                preferredFramesPerSecond: 120,
                options: [.ignoresSiblingOrder],
                debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount]
            )
            .ignoresSafeArea()
        }
        .background(.black)
    }
}

#Preview {
    PileOfBlocksView()
}

// MARK: Scene

class PileOfBlocksScene: SKScene {
    
    // MARK: Properties
    
    let navCamera = NavigationCamera()
    let contentParent = SKNode()
    
    /// Box2D
    private var b2WorldID: b2WorldId = b2_nullWorldId
    static let pointsPerMeter: CGFloat = 150
    
    private struct BodyNode {
        let bodyId: b2BodyId
        weak var node: SKNode?
    }
    
    private var bodyNodes: [BodyNode] = []
    
    private struct JointDebugLine {
        let jointId: b2JointId
        let line: SKShapeNode
    }
    
    private var testJoints: [b2JointId] = []
    private var jointDebugLines: [JointDebugLine] = []
    
    private let palette: [SKColor] = [
        .systemOrange, .systemYellow, .systemTeal,
        .systemRed, .white, .systemGray
    ]
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1 / 60
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// Restart UI
    private let restartButton = SKLabelNode()
    private var shouldRestartSimulation = false
    
    /// Tap state
    private var tapStartLocation: CGPoint?
    private var tapStartTime: TimeInterval?
    
    /// Profiling
    var box2DBeforePhysicsTime: TimeInterval = CACurrentMediaTime()
    var box2DPhysicsProfiler = PhysicsStepProfiler(label: "Box2D physics")
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        view.contentMode = .center
        size = view.bounds.size
        backgroundColor = .darkGray
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        addChild(contentParent)
        
        setupCamera(view: view)
        createRestartButton()
        updateUI(view: view)
        restartSimulation()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        guard let view else { return }
        updateUI(view: view)
    }
    
    override func willMove(from view: SKView) {
        cleanup()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: Cleanup
    
    private func cleanup() {
        removeAllActions()
        removeContent()
        destroyWorld()
        removeAllChildren()
    }
    
    private func removeContent() {
        /// Restart button and camera are not removed.
        contentParent.removeAllChildren()
        
        bodyNodes.removeAll()
        testJoints.removeAll()
        jointDebugLines.removeAll()
        
        cleanupTouch()
    }
    
    private func destroyWorld() {
        if b2World_IsValid(b2WorldID) {
            b2DestroyWorld(b2WorldID)
            b2WorldID = b2_nullWorldId
        }
    }
    
    // MARK: Camera
    
    func setupCamera(view: UIView) {
        navCamera.gesturesView = view
        navCamera.lock = false
        navCamera.lockPan = false
        navCamera.lockScale = false
        navCamera.lockRotation = false
        navCamera.doubleTapToReset = false
        navCamera.maxScale = 50
        navCamera.minScale = 0.01
        navCamera.area = CGSize(width: 10000, height: 10000)
        
        self.camera = navCamera
        addChild(navCamera)
    }
    
    // MARK: UI
    
    private func createRestartButton() {
        restartButton.text = "Restart"
        restartButton.name = "restartButton"
        restartButton.fontName = "Menlo-Bold"
        restartButton.fontSize = 20
        restartButton.fontColor = .white
        navCamera.addChild(restartButton)
    }
    
    private func updateUI(view: SKView) {
        restartButton.position = CGPoint(
            x: 0,
            y: view.bounds.height / 2 - view.safeAreaInsets.top - 35
        )
    }
    
    // MARK: Box2D World
    
    private func setupBox2D() {
        var worldDef = b2DefaultWorldDef()
        worldDef.gravity = b2Vec2(x: 0, y: 0)
        worldDef.restitutionThreshold = 0
        
        b2WorldID = b2CreateWorld(&worldDef)
        
        /// Keep the original scene behavior: every body stays awake.
        b2World_EnableSleeping(b2WorldID, false)
    }
    
    private func restartSimulation() {
        removeAllActions()
        removeContent()
        destroyWorld()
        
        setupBox2D()
        
        createWalls(parent: contentParent)
        createBlocks(parent: contentParent)
        createJointedBlocks(parent: contentParent)
        scheduleGravityDrop(afterSeconds: 2)
        
        lastUpdateTime = nil
        accumulatedTime = 0
    }
    
    // MARK: Gravity
    
    private func scheduleGravityDrop(afterSeconds seconds: TimeInterval) {
        run(.sequence([
            .wait(forDuration: seconds),
            .run { [weak self] in
                guard let self else { return }
                
                b2World_SetGravity(
                    b2WorldID,
                    b2Vec2(x: 0, y: -10)
                )
                
                /// Wake every body once when gravity starts.
                for bodyNode in bodyNodes {
                    b2Body_SetAwake(bodyNode.bodyId, true)
                }
            }
        ]))
    }
    
    // MARK: Explode
    
    private func explode(at scenePoint: CGPoint) {
        var explosion = b2DefaultExplosionDef()
        
        /// Center of explosion in Box2D world meters.
        explosion.position = b2Vec2(
            x: meters(fromPoints: scenePoint.x),
            y: meters(fromPoints: scenePoint.y)
        )
        
        /// Full strength inside this radius.
        explosion.radius = 1
        
        /// Strength fades to zero across this extra distance.
        explosion.falloff = 1
        
        /// Positive pushes away, negative pulls inward.
        explosion.impulsePerLength = 50
        
        b2World_Explode(b2WorldID, &explosion)
    }
    
    // MARK: Walls
    /**
     
     U-shaped container: floor + two walls.
     
     */
    private func createWalls(parent: SKNode) {
        let floorY: CGFloat = -300
        let containerWidth: CGFloat = 10000
        let wallHeight: CGFloat = 10000
        let wallThickness: CGFloat = 15
        
        func makeWall(width: CGFloat, height: CGFloat, position: CGPoint) {
            let wall = SKShapeNode(rectOf: CGSize(width: width, height: height))
            wall.fillColor = .gray
            wall.strokeColor = .black
            wall.lineWidth = 2
            wall.position = position
            parent.addChild(wall)
            
            var bodyDef = b2DefaultBodyDef()
            bodyDef.type = b2_staticBody
            bodyDef.position = b2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            
            let bodyId = b2CreateBody(b2WorldID, &bodyDef)
            
            var shapeDef = b2DefaultShapeDef()
            shapeDef.density = 0
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.1
            
            /// Box2D box dimensions are half extents in meters.
            var polygon = b2MakeBox(
                meters(fromPoints: width / 2),
                meters(fromPoints: height / 2)
            )
            
            b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
            
            bodyNodes.append(BodyNode(bodyId: bodyId, node: wall))
        }
        
        /// Floor: sits at floorY, top edge at floorY + wallThickness / 2.
        makeWall(
            width: containerWidth,
            height: wallThickness,
            position: CGPoint(x: 0, y: floorY)
        )
        
        /// Left wall: extends upward from the floor.
        makeWall(
            width: wallThickness,
            height: wallHeight,
            position: CGPoint(x: -containerWidth / 2, y: floorY + wallHeight / 2)
        )
        
        /// Right wall: extends upward from the floor.
        makeWall(
            width: wallThickness,
            height: wallHeight,
            position: CGPoint(x: containerWidth / 2, y: floorY + wallHeight / 2)
        )
    }
    
    // MARK: Blocks
    /**
     
     Spawn blocks on a grid.
     
     */
    private func createBlocks(parent: SKNode) {
        let columns = 10
        let rows = 10
        let cellSize: CGFloat = 100
        let blockSizes: [CGFloat] = [15, 30, 60, 75, 100]
        let cornerRadius: CGFloat = 9
        let baseY: CGFloat = 1000 /// Y of the lowest row of blocks.
        
        let gridWidth = CGFloat(columns) * cellSize
        let originX = -gridWidth / 2 + cellSize / 2
        let originY = baseY + cellSize / 2
        
        var index = 0
        
        for row in 0..<rows {
            for column in 0..<columns {
                let isRectangle = index.isMultiple(of: 2)
                let width = blockSizes.randomElement()!
                let height = isRectangle ? blockSizes.randomElement()! : width
                let color = palette[index % palette.count]
                
                let block = createNode(
                    isRectangle: isRectangle,
                    width: width,
                    height: height,
                    cornerRadius: cornerRadius,
                    color: color
                )
                
                let xOffset = CGFloat.random(in: -cellSize * 0.1...cellSize * 0.1)
                let yOffset = CGFloat.random(in: -cellSize * 0.1...cellSize * 0.1)
                let position = CGPoint(
                    x: originX + CGFloat(column) * cellSize + xOffset,
                    y: originY + CGFloat(row) * cellSize + yOffset
                )
                
                block.position = position
                parent.addChild(block)
                
                let bodyId = createBody(
                    isRectangle: isRectangle,
                    width: width,
                    height: height,
                    position: position
                )
                
                bodyNodes.append(BodyNode(bodyId: bodyId, node: block))
                index += 1
            }
        }
        
        print("\nBox2D Physics")
        print("\(bodyNodes.count) bodies")
    }
    
    /**
     
     SpriteKit node.
     
     */
    private func createNode(
        isRectangle: Bool,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        color: SKColor
    ) -> SKSpriteNode {
        let texture = ResourceCache.texture(
            isRectangle: isRectangle,
            width: width,
            height: height,
            cornerRadius: cornerRadius
        )
        
        let block = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
        block.color = color
        block.colorBlendFactor = 1
        
        return block
    }
    
    /**
     
     Box2D body.
     
     */
    private func createBody(
        isRectangle: Bool,
        width: CGFloat,
        height: CGFloat,
        position: CGPoint
    ) -> b2BodyId {
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_dynamicBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        bodyDef.linearDamping = 0
        bodyDef.angularDamping = 0.1
        
        let bodyId = b2CreateBody(b2WorldID, &bodyDef)
        
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 2
        shapeDef.material.friction = 0.5
        shapeDef.material.restitution = 0.2
        
        if isRectangle {
            /// Box2D box dimensions are half extents in meters.
            var polygon = b2MakeBox(
                meters(fromPoints: width / 2),
                meters(fromPoints: height / 2)
            )
            
            b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
        } else {
            /// Circle block matches the SpriteKit texture radius.
            var circle = b2Circle(
                center: b2Vec2(x: 0, y: 0),
                radius: meters(fromPoints: width / 2)
            )
            
            b2CreateCircleShape(bodyId, &shapeDef, &circle)
        }
        
        return bodyId
    }
    
    // MARK: Joints
    
    private func createJointedBlocks(parent: SKNode) {
        let blockSize: CGFloat = 75
        let cornerRadius: CGFloat = 9
        let positionA = CGPoint(x: -90, y: 350)
        let positionB = CGPoint(x: 90, y: 350)
        
        /// Visual blocks.
        let blockA = createNode(
            isRectangle: true,
            width: blockSize,
            height: blockSize,
            cornerRadius: cornerRadius,
            color: .systemRed
        )
        blockA.position = positionA
        parent.addChild(blockA)
        
        let blockB = createNode(
            isRectangle: true,
            width: blockSize,
            height: blockSize,
            cornerRadius: cornerRadius,
            color: .systemBlue
        )
        blockB.position = positionB
        parent.addChild(blockB)
        
        /// Box2D bodies.
        let bodyIdA = createBody(
            isRectangle: true,
            width: blockSize,
            height: blockSize,
            position: positionA
        )
        
        let bodyIdB = createBody(
            isRectangle: true,
            width: blockSize,
            height: blockSize,
            position: positionB
        )
        
        bodyNodes.append(BodyNode(bodyId: bodyIdA, node: blockA))
        bodyNodes.append(BodyNode(bodyId: bodyIdB, node: blockB))
        
        /// Distance joint between body centers.
        let worldPointA = b2Vec2(
            x: meters(fromPoints: positionA.x),
            y: meters(fromPoints: positionA.y)
        )
        
        let worldPointB = b2Vec2(
            x: meters(fromPoints: positionB.x),
            y: meters(fromPoints: positionB.y)
        )
        
        let deltaX = worldPointB.x - worldPointA.x
        let deltaY = worldPointB.y - worldPointA.y
        let restLength = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        var jointDef = b2DefaultDistanceJointDef()
        jointDef.base.bodyIdA = bodyIdA
        jointDef.base.bodyIdB = bodyIdB
        jointDef.base.localFrameA.p = b2Body_GetLocalPoint(bodyIdA, worldPointA)
        jointDef.base.localFrameB.p = b2Body_GetLocalPoint(bodyIdB, worldPointB)
        jointDef.length = restLength
        jointDef.enableSpring = false
        
        let jointId = b2CreateDistanceJoint(b2WorldID, &jointDef)
        testJoints.append(jointId)
        
        /// Debug line so the joint is visible in SpriteKit.
        let line = SKShapeNode()
        line.strokeColor = .black
        line.lineCap = .round
        line.lineWidth = 6
        line.zPosition = 100
        parent.addChild(line)
        
        jointDebugLines.append(JointDebugLine(jointId: jointId, line: line))
    }
    
    // MARK: Update
    
    override func update(_ currentTime: TimeInterval) {
        navCamera.update()
        
        /// Calculate delta time from SpriteKit's current time.
        guard let lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime - lastUpdateTime
        self.lastUpdateTime = currentTime
        
        accumulatedTime += deltaTime
    }
    
    override func didSimulatePhysics() {
        while accumulatedTime >= fixedTimestep {
            fixedUpdate(fixedTimestep)
            accumulatedTime -= fixedTimestep
        }
    }
    
    override func didFinishUpdate() {
        syncSpriteKitFromBox2D()
        drawJointDebugLines()
    }
    
    private func fixedUpdate(_ fixedTimestep: TimeInterval) {
        if shouldRestartSimulation {
            shouldRestartSimulation = false
            restartSimulation()
        }
        
        box2DBeforePhysicsTime = CACurrentMediaTime()
        
        /// Step Box2D.
        b2World_Step(b2WorldID, Float(fixedTimestep), 4)
        
        let afterPhysicsTime = CACurrentMediaTime()
        let physicsStepMS = (afterPhysicsTime - box2DBeforePhysicsTime) * 1000
        box2DPhysicsProfiler.record(milliseconds: physicsStepMS)
    }
    
    private func syncSpriteKitFromBox2D() {
        /// Copy Box2D body transforms into SpriteKit nodes.
        for bodyNode in bodyNodes {
            guard let node = bodyNode.node else { continue }
            guard b2Body_IsValid(bodyNode.bodyId) else { continue }
            
            let bodyPosition = b2Body_GetPosition(bodyNode.bodyId)
            let bodyRotation = b2Body_GetRotation(bodyNode.bodyId)
            
            node.position = CGPoint(
                x: points(fromMeters: bodyPosition.x),
                y: points(fromMeters: bodyPosition.y)
            )
            
            node.zRotation = CGFloat(b2Rot_GetAngle(bodyRotation))
        }
    }
    
    private func drawJointDebugLines() {
        /// Draw Box2D joint anchors.
        for jointDebugLine in jointDebugLines {
            guard b2Joint_IsValid(jointDebugLine.jointId) else { continue }
            
            let bodyIdA = b2Joint_GetBodyA(jointDebugLine.jointId)
            let bodyIdB = b2Joint_GetBodyB(jointDebugLine.jointId)
            
            let bodyTransformA = b2Body_GetTransform(bodyIdA)
            let bodyTransformB = b2Body_GetTransform(bodyIdB)
            
            let localFrameA = b2Joint_GetLocalFrameA(jointDebugLine.jointId)
            let localFrameB = b2Joint_GetLocalFrameB(jointDebugLine.jointId)
            
            /// Joint anchors are body-local, so convert them to world coordinates.
            let worldPointA = b2TransformPoint(bodyTransformA, localFrameA.p)
            let worldPointB = b2TransformPoint(bodyTransformB, localFrameB.p)
            
            let path = CGMutablePath()
            path.move(to: CGPoint(
                x: points(fromMeters: worldPointA.x),
                y: points(fromMeters: worldPointA.y)
            ))
            path.addLine(to: CGPoint(
                x: points(fromMeters: worldPointB.x),
                y: points(fromMeters: worldPointB.y)
            ))
            
            jointDebugLine.line.path = path
        }
    }
    
    // MARK: Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        navCamera.stop()
        
        guard let touch = touches.first else { return }
        let position = touch.location(in: self)
        let touchedNodes = nodes(at: position)
        
        if touchedNodes.contains(where: { $0.name == "restartButton" }) {
            shouldRestartSimulation = true
            cleanupTouch()
            return
        }
        
        /// Track tap.
        tapStartLocation = position
        tapStartTime = touch.timestamp
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let tapStartLocation,
              let tapStartTime
        else {
            cleanupTouch()
            return
        }
        
        let tapEndLocation = touch.location(in: self)
        let tapDuration = touch.timestamp - tapStartTime
        let tapMovement = hypot(
            tapEndLocation.x - tapStartLocation.x,
            tapEndLocation.y - tapStartLocation.y
        )
        
        /// Only quick, mostly-stationary touches are taps.
        if tapDuration <= 0.25 && tapMovement <= 12 {
            explode(at: tapEndLocation)
        }
        
        cleanupTouch()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cleanupTouch()
    }
    
    private func cleanupTouch() {
        /// Reset tap state after each completed or cancelled touch.
        tapStartLocation = nil
        tapStartTime = nil
    }
    
    // MARK: Unit Conversion
    
    func meters(fromPoints points: CGFloat) -> Float {
        Float(points / Self.pointsPerMeter)
    }
    
    func points(fromMeters meters: Float) -> CGFloat {
        CGFloat(meters) * Self.pointsPerMeter
    }
    
}


