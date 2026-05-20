/**
 
 # Pile Of Blocks
 
 Pile test.
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 19 May 2026
 
 */
import SwiftUI
import SpriteKit
import SwiftBox2D

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

// MARK: Scene

class PileOfBlocksScene: SKScene {

    // MARK: Properties

    let navCamera = NavigationCamera()
    let contentParent = SKNode()
    
    /// Box2D
    private let b2DWorld = B2World()
    static let pointsPerMeter: CGFloat = 150
    
    private struct BodyNode {
        let body: B2Body
        weak var node: SKNode?
    }
    private var bodyNodes: [BodyNode] = []
    
    private var testJoints: [B2DistanceJoint] = []
    private var jointDebugLines: [(joint: B2DistanceJoint, line: SKShapeNode)] = []
    
    private let palette: [SKColor] = [
        .systemOrange, .systemYellow, .systemTeal,
        .systemRed, .white, .systemGray
    ]
    
    /// Tap state
    private var tapStartLocation: CGPoint?
    private var tapStartTime: TimeInterval?
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        view.contentMode = .center
        size = view.bounds.size
        backgroundColor = .darkGray
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        b2DWorld.gravity = B2Vec2(x: 0, y: 0)
        b2DWorld.enableSleeping(false)
        
        addChild(contentParent)
        
        setupCamera(view: view)
        createWalls(parent: contentParent)
        createBlocks(parent: contentParent)
        createJointedBlocks(parent: contentParent)
        scheduleGravityDrop(afterSeconds: 2)
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
    
    // MARK: Gravity
    
    private func scheduleGravityDrop(afterSeconds seconds: TimeInterval) {
        run(.sequence([
            .wait(forDuration: seconds),
            .run { [weak self] in
                self?.b2DWorld.gravity = B2Vec2(x: 0, y: -10)
            }
        ]))
    }
    
    // MARK: Explode
    
    private func explode(at scenePoint: CGPoint) {
        var explosion = b2ExplosionDef.default()
        
        /// Center of explosion in Box2D world meters.
        explosion.position = B2Vec2(
            x: meters(fromPoints: scenePoint.x),
            y: meters(fromPoints: scenePoint.y)
        )
        
        /// Full strength inside this radius.
        explosion.radius = 1
        
        /// Strength fades to zero across this extra distance.
        explosion.falloff = 1.0
        
        /// Positive pushes away, negative pulls inward.
        explosion.impulsePerLength = 50.0
        
        b2DWorld.explode(explosion)
    }
    
    // MARK: Walls
    /**
     
     U-shaped container: floor + two walls.
     
     */
    private func createWalls(parent: SKNode) {
        let floorY: CGFloat = -300
        let containerWidth: CGFloat = 5000
        let wallHeight: CGFloat = 10000
        let wallThickness: CGFloat = 15
        
        func makeWall(width: CGFloat, height: CGFloat, position: CGPoint) {
            let wall = SKShapeNode(rectOf: CGSize(width: width, height: height))
            wall.fillColor = .gray
            wall.strokeColor = .black
            wall.lineWidth = 2
            wall.position = position
            parent.addChild(wall)
            
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2StaticBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            
            let body = b2DWorld.createBody(bodyDef)
            
            var shapeDef = b2ShapeDef.default()
            shapeDef.density = 0
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.1
            
            /// Box2D box dimensions are half extents in meters.
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: width / 2),
                halfHeight: meters(fromPoints: height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
        }
        
        /// Floor: sits at floorY, top edge at floorY + wallThickness/2
        makeWall(
            width: containerWidth,
            height: wallThickness,
            position: CGPoint(x: 0, y: floorY)
        )
        
        /// Left wall: extends upward from the floor
        makeWall(
            width: wallThickness,
            height: wallHeight,
            position: CGPoint(x: -containerWidth / 2, y: floorY + wallHeight / 2)
        )
        
        /// Right wall: extends upward from the floor
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
        let columns = 50
        let rows = 50
        let cellSize: CGFloat = 100
        let blockSizes: [CGFloat] = [15, 30, 60, 75, 100]
        let baseY: CGFloat = 1000 /// Y of the lowest row of blocks
        
        let gridWidth = CGFloat(columns) * cellSize
        let originX = -gridWidth / 2 + cellSize / 2
        let originY = baseY + cellSize / 2
        
        var index = 0
        for row in 0..<rows {
            for column in 0..<columns {
                let isRectangle = (index % 2 == 0)
                let width = blockSizes.randomElement()!
                let height = isRectangle ? blockSizes.randomElement()! : width
                let color = palette[index % palette.count]
                
                let block = createNode(
                    isRectangle: isRectangle,
                    width: width,
                    height: height,
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
                
                let body = createBody(
                    isRectangle: isRectangle,
                    width: width,
                    height: height,
                    position: position
                )
                
                bodyNodes.append(BodyNode(body: body, node: block))
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
        color: SKColor
    ) -> SKSpriteNode {
        let texture = ResourceCache.texture(
            isRectangle: isRectangle,
            width: width,
            height: height
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
    ) -> B2Body {
        var bodyDef = b2BodyDef.default()
        bodyDef.type = .b2DynamicBody
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        bodyDef.linearDamping = 0
        bodyDef.angularDamping = 0.1
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 2
        shapeDef.material.friction = 0.5
        shapeDef.material.restitution = 0.2
        
        if isRectangle {
            /// Box2D box dimensions are half extents in meters.
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: width / 2),
                halfHeight: meters(fromPoints: height / 2)
            )
            body.createShape(polygon, shapeDef: shapeDef)
        } else {
            /// Circle block matches SpriteKit's circleOfRadius(width / 2).
            let circle = B2Circle(
                center: B2Vec2(x: 0, y: 0),
                radius: meters(fromPoints: width / 2)
            )
            body.createShape(circle, shapeDef: shapeDef)
        }
        
        return body
    }
    
    // MARK: Joints
    
    private func createJointedBlocks(parent: SKNode) {
        let blockSize: CGFloat = 75
        let positionA = CGPoint(x: -90, y: 350)
        let positionB = CGPoint(x: 90, y: 350)
        
        /// Visual blocks
        let blockA = createNode(isRectangle: true, width: blockSize, height: blockSize, color: .systemRed)
        blockA.position = positionA
        parent.addChild(blockA)
        
        let blockB = createNode(isRectangle: true, width: blockSize, height: blockSize, color: .systemBlue)
        blockB.position = positionB
        parent.addChild(blockB)
        
        /// Box2D bodies
        let bodyA = createBody(isRectangle: true, width: blockSize, height: blockSize, position: positionA)
        let bodyB = createBody(isRectangle: true, width: blockSize, height: blockSize, position: positionB)
        
        bodyNodes.append(BodyNode(body: bodyA, node: blockA))
        bodyNodes.append(BodyNode(body: bodyB, node: blockB))
        
        /// Distance joint between body centers
        let worldPointA = B2Vec2(x: meters(fromPoints: positionA.x), y: meters(fromPoints: positionA.y))
        let worldPointB = B2Vec2(x: meters(fromPoints: positionB.x), y: meters(fromPoints: positionB.y))
        let deltaX = worldPointB.x - worldPointA.x
        let deltaY = worldPointB.y - worldPointA.y
        let restLength = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        var jointDef = b2DistanceJointDef.default()
        jointDef.bodyA = bodyA
        jointDef.bodyB = bodyB
        jointDef.length = restLength
        jointDef.enableSpring = false
        
        let joint = b2DWorld.createJoint(jointDef)
        testJoints.append(joint)
        
        /// Debug line so the joint is visible in SpriteKit
        let line = SKShapeNode()
        line.strokeColor = .black
        line.lineCap = .round
        line.lineWidth = 6
        line.zPosition = 100
        parent.addChild(line)
        
        jointDebugLines.append((joint: joint, line: line))
    }
    
    // MARK: Update
    
    var box2DBeforePhysicsTime: TimeInterval = CACurrentMediaTime()
    var box2DPhysicsProfiler = PhysicsStepProfiler(label: "Box2D physics")
    
    override func update(_ currentTime: TimeInterval) {
        navCamera.update()
        
        box2DBeforePhysicsTime = CACurrentMediaTime()
        
        /// Step Box2D
        b2DWorld.step(1.0 / 60.0, subSteps: 4)
        
        let afterPhysicsTime = CACurrentMediaTime()
        let physicsStepMS = (afterPhysicsTime - box2DBeforePhysicsTime) * 1000
        box2DPhysicsProfiler.record(milliseconds: physicsStepMS)
        
        /// Copy Box2D body transforms into SpriteKit nodes.
        for pair in bodyNodes {
            guard let node = pair.node else { continue }
            
            let bodyPosition = pair.body.getPosition()
            let bodyRotation = pair.body.getRotation()
            
            node.position = CGPoint(
                x: points(fromMeters: bodyPosition.x),
                y: points(fromMeters: bodyPosition.y)
            )
            node.zRotation = CGFloat(bodyRotation.angle)
        }
        
        /// Draw Box2D joint anchors
        for jointDebugLine in jointDebugLines {
            let worldPointA = jointDebugLine.joint.worldPointA()
            let worldPointB = jointDebugLine.joint.worldPointB()
            
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
        guard let touch = touches.first else { return }
        
        navCamera.stop()
        
        /// Track tap
        tapStartLocation = touch.location(in: self)
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


