/**
 
 # Joints
 
 Physics joints test scene wtih SpriteKit and Box2D v3
 
 ## Notes
 
 Run in release mode, not in debug mode.
 Box2D is slow in debug mode, and fast in release mode.
 
 Achraf Kassioui
 Created 22 May 2026
 Updated 22 May 2026
 
 */
import SpriteKit
import SwiftUI
import SwiftBox2D
import Observation

// MARK: View

struct JointsView: View {
    @State var scene = JointsScene()
    
    var body: some View {
        ZStack {
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: 120,
                options: [.ignoresSiblingOrder],
                debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount, .showsQuadCount]
            )
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    /// Zoom out
                    ToggleButton(
                        isOn: false,
                        onText: "",
                        offText: "",
                        onSystemImage: "minus",
                        offSystemImage: "minus",
                        action: {
                            let zoomFactor: CGFloat = 1.25
                            
                            scene.navCamera.setTo(
                                xScale: scene.navCamera.xScale * zoomFactor,
                                yScale: scene.navCamera.yScale * zoomFactor
                            )
                        }
                    )
                    
                    /// Reset zoom to 1:1
                    ToggleButton(
                        isOn: false,
                        onText: "\(scene.cameraZoomPercent)%",
                        offText: "\(scene.cameraZoomPercent)%",
                        onSystemImage: "",
                        offSystemImage: "",
                        action: {
                            scene.navCamera.setTo(
                                xScale: 1,
                                yScale: 1
                            )
                        }
                    )
                    
                    /// Zoom in
                    ToggleButton(
                        isOn: false,
                        onText: "",
                        offText: "",
                        onSystemImage: "plus",
                        offSystemImage: "plus",
                        action: {
                            let zoomFactor: CGFloat = 0.8
                            
                            scene.navCamera.setTo(
                                xScale: scene.navCamera.xScale * zoomFactor,
                                yScale: scene.navCamera.yScale * zoomFactor
                            )
                        }
                    )
                    
                    Spacer()
                    
                    /// Content
                    ToggleButton(
                        isOn: false,
                        onText: "Blocks",
                        offText: "Blocks",
                        onSystemImage: "square.grid.4x3.fill",
                        offSystemImage: "square.grid.4x3.fill",
                        action: {
                            scene.createContent()
                        }
                    )
                }
                Spacer()
                HStack {
                    /// Camera mode
                    ToggleButton(
                        isOn: scene.cameraDragOnly == false,
                        onText: "Dragging Is Enabled",
                        offText: "Dragging Is Disabled",
                        onSystemImage: "hand.draw.fill",
                        offSystemImage: "hand.raised.fill",
                        action: {
                            scene.cameraDragOnly.toggle()
                            if scene.cameraDragOnly {
                                scene.endDrags(wakeAttached: true)
                            }
                        }
                    )
                    
                    Spacer()
                }
            }
            .padding()
        }
        .background(.black)
    }
}

#Preview {
    JointsView()
}

// MARK: Scene

@Observable
class JointsScene: SKScene, NavigationCameraDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    /// Camera
    let navCamera = NavigationCamera()
    var cameraDragOnly = false
    var cameraZoomPercent = 100
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1/60
    private var physicsSpeed: CGFloat = 1
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// Box2D
    private static let pointsPerMeter: CGFloat = 150 /// In SpriteKit, 150 points = 1 meter
    private let gravityLength: Float = 10
    private let b2DWorld = B2World()
    private let debugRenderer = Box2DDebugRenderer(pointsPerMeter: pointsPerMeter)
    var debugPhysics: Bool = false /// Warning, if there are too many nodes, app may crash or framerate may tank.
    
    enum PhysicsCategory {
        static let wall: UInt64 = 0x0001
        static let chain: UInt64 = 0x0002
        static let block: UInt64 = 0x0004
    }
    
    /// Entities
    private struct Entity {
        weak var node: SKNode?
        let body: B2Body
    }
    private var entities: [B2BodyId: Entity] = [:]
    
    /// Layers
    enum ZPosition {
        static let background: CGFloat = 0
        static let content: CGFloat = 1
        static let viz: CGFloat = 2
        static let UI: CGFloat = 3
    }
    
    /// Joints
    private struct WeldJoint {
        let joint: B2WeldJoint
        let bodyA: B2Body
        let bodyB: B2Body
        let jointViz: SKShapeNode
    }
    private var weldJoints: [WeldJoint] = []
    
    /// Dragging
    private struct DragState {
        let pointerEntity: Entity
        let joint: B2MotorJoint
        let jointViz: SKShapeNode
        var targetPosition: B2Vec2
        let targetRotation: B2Rot
    }
    private var activeDrags: [UITouch: DragState] = [:]
    private let shouldMaintainAngle = false
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        view.contentMode = .center
        view.isMultipleTouchEnabled = true
        size = view.bounds.size
        scaleMode = .resizeFill
        backgroundColor = .darkGray
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        /// Camera
        setupCamera(view: view)
        
        /// Box2D
        setupBox2D()
        
        /// Box2D debug
        addChild(debugRenderer.node)
        
        /// Content
        createContent()
    }
    
    override func willMove(from view: SKView) {
        removeContent()
        self.removeAllChildren()
    }
    
    deinit {
        removeContent()
        self.removeAllChildren()
    }
    
    // MARK: Box2D World
    
    private func setupBox2D() {
        b2DWorld.gravity = B2Vec2(x: 0, y: 0)
        b2DWorld.restitutionThreshold = 0
        
        let action = SKAction.sequence([
            .wait(forDuration: 2),
            .run { [weak self] in
                guard let self else { return }
                b2DWorld.gravity = B2Vec2(x: 0, y: -gravityLength)
                
                for entity in entities.values {
                    entity.body.setAwake(true)
                }
            }
        ])
        action.timingMode = .linear
        run(action)
    }
    
    // MARK: Camera
    
    func setupCamera(view: UIView) {
        navCamera.gestureRecognizerDelegate = self
        navCamera.delegate = self
        navCamera.gesturesView = view
        navCamera.lock = false
        navCamera.lockPan = false
        navCamera.lockScale = false
        navCamera.lockRotation = true
        navCamera.doubleTapToReset = false
        navCamera.maxScale = 50
        navCamera.minScale = 0.01
        
        self.camera = navCamera
        addChild(navCamera)
    }
    
    func cameraDidMove(to position: CGPoint) {
        
    }
    
    func cameraDidRotate(to angle: CGFloat) {
        
    }
    
    func cameraDidScale(to scale: CGPoint) {
        /// Scale is inverse zoom
        cameraZoomPercent = Int((1 / scale.x * 100).rounded())
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: Content
    
    func createContent() {
        guard let view = self.view else { return }
        removeContent()
        createWalls(view: view)
        createWeldJoints()
        //createRevoluteChain()
    }
    
    private func removeContent() {
        /// Destroy drag joints first because they reference bodies.
        endDrags(wakeAttached: false)
        
        /// Destroy weld joints before destroying their connected bodies.
        for weldJoint in weldJoints {
            weldJoint.joint.destroy(wakeAttached: false)
            weldJoint.jointViz.removeFromParent()
        }
        
        weldJoints.removeAll()
        
        /// Remove all SpriteKit nodes and Box2D bodies owned by the scene content.
        for entity in entities.values {
            removeEntity(entity)
        }
        
        entities.removeAll()
    }
    
    private func removeEntity(_ entity: Entity) {
        entity.node?.removeFromParent()
        entity.body.destroy()
    }
    
    // MARK: Pointer
    
    private func createPointerBodyNode(touchRadius: CGFloat, position: B2Vec2, rotation: B2Rot) -> Entity {
        /// Visual pointer
        let pointerNode = SKShapeNode(circleOfRadius: touchRadius)
        pointerNode.fillColor = SKColor.systemCyan.withAlphaComponent(0.5)
        pointerNode.strokeColor = .black
        pointerNode.lineWidth = 3
        pointerNode.position = CGPoint(
            x: points(fromMeters: position.x),
            y: points(fromMeters: position.y)
        )
        pointerNode.zRotation = CGFloat(rotation.angle)
        pointerNode.zPosition = ZPosition.UI
        addChild(pointerNode)
        
        /// Pointer body: kinematic target used by the motor joint
        var bodyDef = b2BodyDef.default()
        bodyDef.type = .b2KinematicBody
        bodyDef.position = position
        bodyDef.rotation = rotation
        bodyDef.enableSleep = false
        
        /// No shape is needed, the joint only needs a body
        let pointerBody = b2DWorld.createBody(bodyDef)
        
        let entity = Entity(
            node: pointerNode,
            body: pointerBody,
        )
        
        entities[pointerBody.id] = entity
        
        return entity
    }
    
    // MARK: Walls
    
    private func createWalls(view: SKView) {
        let thickness: CGFloat = 15
        let baseWidth: CGFloat = 2000
        let sideHeight: CGFloat = 20000
        
        /// Ground center Y, relative to scene origin.
        let baseY: CGFloat = -300
        
        let baseSize = CGSize(width: baseWidth, height: thickness)
        let sideSize = CGSize(width: thickness, height: sideHeight)
        
        let basePosition = CGPoint(x: 0, y: baseY)
        
        /// Side walls grow upward from the top of the base.
        let sideY = baseY + thickness / 2 + sideHeight / 2
        
        let leftPosition = CGPoint(
            x: -baseWidth / 2 + thickness / 2,
            y: sideY
        )
        
        let rightPosition = CGPoint(
            x: baseWidth / 2 - thickness / 2,
            y: sideY
        )
        
        let sizes = [baseSize, sideSize, sideSize]
        let positions = [basePosition, leftPosition, rightPosition]
        
        for index in sizes.indices {
            let size = sizes[index]
            let position = positions[index]
            
            /// Rendering
            let node = SKShapeNode(rectOf: size)
            node.fillColor = .gray
            node.strokeColor = .black
            node.lineWidth = 2
            node.position = position
            node.zPosition = ZPosition.background
            addChild(node)
            
            /// Box2D body
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2StaticBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            
            let body = b2DWorld.createBody(bodyDef)
            
            var shapeDef = b2ShapeDef.default()
            shapeDef.density = 0
            shapeDef.filter.categoryBits = PhysicsCategory.wall
            
            /// Static container parts are simple rectangle collision shapes
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: size.width / 2),
                halfHeight: meters(fromPoints: size.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            entities[body.id] = Entity(node: node, body: body)
        }
    }
    
    // MARK: Chain
    
    private func createChain() {
        
    }
    
    // MARK: Revolute Chain
    
    private func createRevoluteChain(linksShouldCollideWithEachOther: Bool = true) {
        let blockCount = 500
        let cellSize: CGFloat = 44
        let blockSize = CGSize(width: 20, height: 38)
        /// Lowest block center Y, the chain grows upward
        let startPosition = CGPoint(x: 0, y: -150)
        let colors: [SKColor] = [.systemOrange, .systemYellow, .systemTeal, .systemRed, .white, .systemGray]
        
        var chainEntities: [Entity] = []
        
        for index in 0..<blockCount {
            let position = CGPoint(
                x: startPosition.x,
                y: startPosition.y + CGFloat(index) * cellSize
            )
            
            /// SpriteKit visual
            let texture = ResourceCache.texture(
                isRectangle: true,
                width: blockSize.width,
                height: blockSize.height,
                cornerRadius: 6
            )
            
            let node = SKSpriteNode(texture: texture, size: blockSize)
            node.colorBlendFactor = 1
            node.color = colors.randomElement() ?? .systemYellow
            node.zPosition = ZPosition.content
            addChild(node)
            
            /// Box2D body
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2DynamicBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            bodyDef.linearDamping = 1
            bodyDef.angularDamping = 1
            bodyDef.gravityScale = 2
            
            let body = b2DWorld.createBody(bodyDef)
            
            /// Box2D material
            var shapeDef = b2ShapeDef.default()
            shapeDef.density = 1
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.2
            shapeDef.filter.categoryBits = PhysicsCategory.chain
            shapeDef.filter.maskBits = linksShouldCollideWithEachOther ? PhysicsCategory.wall | PhysicsCategory.chain : PhysicsCategory.wall
            
            /// Rectangle collision shape
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: blockSize.width / 2),
                halfHeight: meters(fromPoints: blockSize.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            let entity = Entity(node: node, body: body)
            chainEntities.append(entity)
            entities[body.id] = Entity(node: node, body: body)
        }
        
        for index in 0..<(chainEntities.count - 1) {
            let bodyA = chainEntities[index].body
            let bodyB = chainEntities[index + 1].body
            
            let bodyAPosition = bodyA.getPosition()
            let bodyBPosition = bodyB.getPosition()
            
            /// Midpoint
            let anchorPosition = B2Vec2(
                x: (bodyAPosition.x + bodyBPosition.x) / 2,
                y: (bodyAPosition.y + bodyBPosition.y) / 2
            )
            
            /// Revolute joint connects two blocks at a pivot while allowing rotation
            var jointDef = b2RevoluteJointDef.default()
            jointDef.bodyA = bodyA
            jointDef.bodyB = bodyB
            jointDef.base.collideConnected = false
            jointDef.enableLimit = true
            jointDef.lowerAngle = -.pi / 2
            jointDef.upperAngle = .pi / 2
            
            /// Box2D joint anchors are expressed in body-local coordinates
            jointDef.base.localFrameA.p = bodyA.getLocalPoint(anchorPosition)
            jointDef.base.localFrameB.p = bodyB.getLocalPoint(anchorPosition)
            
            _ = b2DWorld.createJoint(jointDef)
        }
    }
    
    // MARK: Weld Joints
    
    private func createWeldJoints() {
        let columns = 2
        let rows = 2
        let cellSize: CGFloat = 82
        let blockSize = CGSize(width: 75, height: 75)
        let cornerRadius: CGFloat = 9
        let colors: [SKColor] = [.systemOrange, .systemYellow, .systemTeal, .systemRed, .white, .systemGray]
        let startY: CGFloat = -150
        
        /// Start at the bottom-left of the grid, then grow right and up
        let startX = -CGFloat(columns - 1) * cellSize / 2
        
        var gridEntities: [[Entity]] = []
        
        for row in 0..<rows {
            var rowEntities: [Entity] = []
            
            for column in 0..<columns {
                let position = CGPoint(
                    x: startX + CGFloat(column) * cellSize,
                    y: startY + CGFloat(row) * cellSize
                )
                
                /// SpriteKit visual
                let texture = ResourceCache.texture(
                    isRectangle: true,
                    width: blockSize.width,
                    height: blockSize.height,
                    cornerRadius: cornerRadius
                )
                
                let node = SKSpriteNode(texture: texture, size: blockSize)
                node.colorBlendFactor = 1
                node.color = colors.randomElement() ?? .systemYellow
                node.position = position
                node.zPosition = ZPosition.content
                addChild(node)
                
                /// Box2D body
                var bodyDef = b2BodyDef.default()
                bodyDef.type = .b2DynamicBody
                bodyDef.position = B2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                bodyDef.linearDamping = 0.5
                bodyDef.angularDamping = 0.5
                bodyDef.gravityScale = 4
                
                let body = b2DWorld.createBody(bodyDef)
                
                /// Box2D material
                var shapeDef = b2ShapeDef.default()
                shapeDef.density = 1
                shapeDef.material.friction = 0.5
                shapeDef.material.restitution = 0.2
                
                /// Collision shape
                let clampedCornerRadius = min(
                    cornerRadius,
                    blockSize.width / 2,
                    blockSize.height / 2
                )
                
                /// Box2D rounded boxes are a core box inflated by radius, so subtract the radius to keep the total size true to the texture
                let roundedRadius = meters(fromPoints: clampedCornerRadius)
                let innerHalfWidth = max(0.001, meters(fromPoints: blockSize.width / 2 - clampedCornerRadius))
                let innerHalfHeight = max(0.001, meters(fromPoints: blockSize.height / 2 - clampedCornerRadius))
                
                /// Rounded polygon shape
                let roundedPolygon = b2MakeRoundedBox(
                    innerHalfWidth,
                    innerHalfHeight,
                    roundedRadius
                )
                
                body.createShape(roundedPolygon, shapeDef: shapeDef)
                
                let entity = Entity(node: node, body: body)
                rowEntities.append(entity)
                entities[body.id] = Entity(node: node, body: body)
            }
            
            gridEntities.append(rowEntities)
        }
        
        for row in 0..<rows {
            for column in 0..<columns {
                let currentEntity = gridEntities[row][column]
                
                if column + 1 < columns {
                    let rightEntity = gridEntities[row][column + 1]
                    
                    /// Connect this block to the block on its right
                    var jointDef = b2WeldJointDef.default()
                    jointDef.bodyA = currentEntity.body
                    jointDef.bodyB = rightEntity.body
                    jointDef.linearHertz = 0
                    jointDef.angularHertz = 0
                    jointDef.base.collideConnected = false
                    
                    let currentPosition = currentEntity.body.getPosition()
                    let rightPosition = rightEntity.body.getPosition()
                    let anchorPosition = B2Vec2(
                        x: (currentPosition.x + rightPosition.x) / 2,
                        y: (currentPosition.y + rightPosition.y) / 2
                    )
                    
                    /// Box2D joint anchors are expressed in body-local coordinates
                    jointDef.base.localFrameA.p = currentEntity.body.getLocalPoint(anchorPosition)
                    jointDef.base.localFrameB.p = rightEntity.body.getLocalPoint(anchorPosition)
                    
                    let joint = b2DWorld.createJoint(jointDef)
                    
                    /// Joint visualization
                    let jointViz = SKShapeNode()
                    jointViz.strokeColor = .black
                    jointViz.lineWidth = 3
                    jointViz.lineCap = .round
                    jointViz.zPosition = ZPosition.background
                    addChild(jointViz)
                    
                    weldJoints.append(WeldJoint(
                        joint: joint,
                        bodyA: currentEntity.body,
                        bodyB: rightEntity.body,
                        jointViz: jointViz
                    ))
                }
                
                if row + 1 < rows {
                    let topEntity = gridEntities[row + 1][column]
                    
                    /// Connect this block to the block above it
                    var jointDef = b2WeldJointDef.default()
                    jointDef.bodyA = currentEntity.body
                    jointDef.bodyB = topEntity.body
                    jointDef.linearHertz = 0
                    jointDef.angularHertz = 0
                    jointDef.base.collideConnected = false
                    
                    let currentPosition = currentEntity.body.getPosition()
                    let topPosition = topEntity.body.getPosition()
                    let anchorPosition = B2Vec2(
                        x: (currentPosition.x + topPosition.x) / 2,
                        y: (currentPosition.y + topPosition.y) / 2
                    )
                    
                    /// Box2D joint anchors are expressed in body-local coordinates
                    jointDef.base.localFrameA.p = currentEntity.body.getLocalPoint(anchorPosition)
                    jointDef.base.localFrameB.p = topEntity.body.getLocalPoint(anchorPosition)
                    
                    let joint = b2DWorld.createJoint(jointDef)
                    
                    /// Joint visualization
                    let jointViz = SKShapeNode()
                    jointViz.strokeColor = .black
                    jointViz.lineWidth = 3
                    jointViz.lineCap = .round
                    jointViz.zPosition = ZPosition.background
                    addChild(jointViz)
                    
                    weldJoints.append(WeldJoint(
                        joint: joint,
                        bodyA: currentEntity.body,
                        bodyB: topEntity.body,
                        jointViz: jointViz
                    ))
                }
            }
        }
    }
    
    // MARK: Update
    
    override func update(_ currentTime: TimeInterval) {
        /// Calculate delta time
        guard let lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        
        let deltaTime = currentTime - lastUpdateTime
        self.lastUpdateTime = currentTime
        
        /// Convert current time into fixed time step
        accumulatedTime += deltaTime * physicsSpeed
        
        /// Run systems that update once per rendered frame
        navCamera.lock = !activeDrags.isEmpty
        navCamera.update()
    }
    
    override func didEvaluateActions() {
        navCamera.didEvaluateActions()
    }
    
    override func didSimulatePhysics() {
        while accumulatedTime >= fixedTimestep {
            /// Run systems on fixed time steps
            fixedUpdate(fixedTimestep)
            
            accumulatedTime -= fixedTimestep
        }
    }
    
    override func didApplyConstraints() {
        
    }
    
    override func didFinishUpdate() {
        /// Use Box2D body events to efficiently sync with SpriteKit nodes
        let bodyEvents = b2DWorld.getBodyEvents()

        /// If no body moved, return
        guard let moveEvents = bodyEvents.moveEvents else { return }
        
        /**
         
         Box2D gives body move events as two separate pieces:
         
         - moveEvents: a memory address to the first event in a C array
         - moveCount: how many move events are stored there
         
         The events are stored next to each other in memory.
         Swift does not see this as a normal Array, so we convert moveCount to Int and use it as loop counter.
         
         */
        for index in 0..<Int(bodyEvents.moveCount) {
            let moveEvent = moveEvents[index]
            
            guard let entity = entities[moveEvent.bodyId] else { continue }
            guard let node = entity.node else { continue }
            
            node.position = CGPoint(
                x: points(fromMeters: moveEvent.transform.p.x),
                y: points(fromMeters: moveEvent.transform.p.y)
            )
            
            node.zRotation = CGFloat(moveEvent.transform.q.angle)
            
            if moveEvent.fellAsleep {
                /// Optional: mark this entity as sleeping
            }
        }
        
        /// Draw dragging joints
        for drag in activeDrags.values {
            let worldPointA = drag.pointerEntity.body.getTransform().transform(
                drag.joint.localFrameA.p
            )
            
            let draggedBody = B2Body(id: drag.joint.getBodyB())
            
            let worldPointB = draggedBody.getTransform().transform(
                drag.joint.localFrameB.p
            )
            
            let pointA = CGPoint(
                x: points(fromMeters: worldPointA.x),
                y: points(fromMeters: worldPointA.y)
            )
            
            let pointB = CGPoint(
                x: points(fromMeters: worldPointB.x),
                y: points(fromMeters: worldPointB.y)
            )
            
            let path = CGMutablePath()
            path.move(to: pointA)
            path.addLine(to: pointB)
            
            /// Draw the dragged-body anchor at body B
            path.addEllipse(in: CGRect(
                x: pointB.x - 8,
                y: pointB.y - 8,
                width: 16,
                height: 16
            ))
            
            drag.jointViz.path = path
        }
        
        /// Draw weld joint lines between connected body centers
        for weldJoint in weldJoints {
            let bodyAPosition = weldJoint.bodyA.getPosition()
            let bodyBPosition = weldJoint.bodyB.getPosition()
            
            let pointA = CGPoint(
                x: points(fromMeters: bodyAPosition.x),
                y: points(fromMeters: bodyAPosition.y)
            )
            
            let pointB = CGPoint(
                x: points(fromMeters: bodyBPosition.x),
                y: points(fromMeters: bodyBPosition.y)
            )
            
            let path = CGMutablePath()
            path.move(to: pointA)
            path.addLine(to: pointB)
            
            weldJoint.jointViz.path = path
        }
        
        /// Box2D debug draw
        if debugPhysics {
            debugRenderer.draw(world: b2DWorld)
        } else {
            debugRenderer.clear()
        }
    }
    
    // MARK: Fixed Update
    
    private func fixedUpdate(_ fixedTimestep: TimeInterval) {
        /// Move pointer
        for drag in activeDrags.values {
            drag.pointerEntity.body.setTargetTransform( /// move by setting velocity, not teleport
                B2Transform(p: drag.targetPosition, q: drag.targetRotation), /// p is position, q is rotation
                Float(fixedTimestep),
                true /// Wake from sleep
            )
        }
        
        /// Step Box2D with the fixed timestep
        b2DWorld.step(Float(fixedTimestep), subSteps: 4)
    }
    
    // MARK: Touch Began
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard cameraDragOnly == false else {
            navCamera.stop()
            return
        }
        
        for touch in touches {
            let scenePosition = touch.location(in: self)
            let touchRadius: CGFloat = 11
            
            /// Find the dynamic Box2D body under this touch
            guard let draggedBodyNode = entity(at: scenePosition, touchRadius: touchRadius) else {
                navCamera.stop()
                continue
            }
            
            /// Convert from SpriteKit to Box2D
            let worldPosition = B2Vec2(
                x: meters(fromPoints: scenePosition.x),
                y: meters(fromPoints: scenePosition.y)
            )
            
            /// Store the dragged body orientation
            let targetRotation = draggedBodyNode.body.getRotation()
            
            /// Create a pointer: kinematic, follow the finger
            let pointerBodyNode = createPointerBodyNode(
                touchRadius: touchRadius,
                position: worldPosition,
                rotation: targetRotation
            )
            
            /// Define a motor joint
            var jointDef = b2MotorJointDef.default()
            jointDef.base.bodyIdA = pointerBodyNode.body.id
            jointDef.base.bodyIdB = draggedBodyNode.body.id
            
            /// Box2D joints anchor are expressed in the body local coordinates
            let pointerAnchor = pointerBodyNode.body.getLocalPoint(worldPosition)
            let draggedAnchor = draggedBodyNode.body.getLocalPoint(worldPosition)
            
            jointDef.base.localFrameA.p = pointerAnchor
            jointDef.base.localFrameB.p = draggedAnchor
            
            /// Spring tuning: lower hertz/force is softer, higher is more direct
            jointDef.linearHertz = 7.5
            jointDef.linearDampingRatio = 1
            
            let massData = draggedBodyNode.body.massData
            let gravityStrength = max(b2DWorld.gravity.length, gravityLength)
            let bodyWeight = max(massData.mass * gravityStrength, 1.0)
            
            jointDef.maxSpringForce = 580 * bodyWeight
            
            if massData.mass > 0.0 {
                let lever = sqrt(massData.rotationalInertia / massData.mass)
                
                if shouldMaintainAngle {
                    /// Angular spring keeps the dragged body close to its starting rotation
                    jointDef.angularHertz = 10
                    jointDef.angularDampingRatio = 1.0
                    jointDef.maxSpringTorque = 500.0 * lever * bodyWeight
                } else {
                    /// Angular velocity torque = spin friction
                    jointDef.maxVelocityTorque = 0.25 * lever * bodyWeight
                    jointDef.maxSpringTorque = 0
                }
            }
            
            let joint = b2DWorld.createJoint(jointDef)
            
            /// Visualize the joint
            let jointVizNode = SKShapeNode()
            jointVizNode.strokeColor = .black
            jointVizNode.fillColor = .black
            jointVizNode.lineWidth = 3
            jointVizNode.lineCap = .round
            jointVizNode.zPosition = ZPosition.viz
            addChild(jointVizNode)
            
            /// Store drag state
            activeDrags[touch] = DragState(
                pointerEntity: pointerBodyNode,
                joint: joint,
                jointViz: jointVizNode,
                targetPosition: worldPosition,
                targetRotation: targetRotation
            )
        }
    }
    
    // MARK: Touch Moved
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let scenePosition = touch.location(in: self)
            
            guard var drag = activeDrags[touch] else { continue }
            
            /// Store intended target
            drag.targetPosition = B2Vec2(
                x: meters(fromPoints: scenePosition.x),
                y: meters(fromPoints: scenePosition.y)
            )
            
            activeDrags[touch] = drag
        }
    }
    
    // MARK: Touch Ended
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrags(for: touches, wakeAttached: true)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrags(for: touches, wakeAttached: true)
    }
    
    // MARK: End Drag
    
    func endDrags(for touches: Set<UITouch>? = nil, wakeAttached: Bool) {
        for (touch, drag) in activeDrags {
            if let touches, touches.contains(touch) == false { continue }
            
            let pointerBodyId = drag.pointerEntity.body.id
            
            /// Remove storage first, before destroying the body mutates its id.
            entities[pointerBodyId] = nil
            activeDrags.removeValue(forKey: touch)
            
            /// Destroy objects after they are no longer reachable from scene storage.
            drag.joint.destroy(wakeAttached: wakeAttached)
            drag.jointViz.removeFromParent()
            removeEntity(drag.pointerEntity)
        }
    }
    
    // MARK: Hit Detection
    
    private func entity(at scenePosition: CGPoint, touchRadius: CGFloat) -> Entity? {
        let touchRadiusMeters = meters(fromPoints: touchRadius)
        
        let worldPosition = B2Vec2(
            x: meters(fromPoints: scenePosition.x),
            y: meters(fromPoints: scenePosition.y)
        )
        
        var probeCenter = B2Vec2(x: 0, y: 0)
        
        /// The touch probe is a small circle placed at the touch position
        let probe = withUnsafePointer(to: &probeCenter) { probeCenterPointer in
            b2MakeOffsetProxy(
                probeCenterPointer,
                1,
                touchRadiusMeters,
                worldPosition,
                .identity
            )
        }
        
        var hitEntities: [Entity] = []
        
        /// Ask Box2D which collision shapes overlap the touch footprint
        b2DWorld.overlapShape(probe, filter: .default()) { shape in
            let bodyId = shape.getBody()
            
            guard let entity = entities[bodyId] else {
                return true
            }
            
            guard entity.body.type == .b2DynamicBody else {
                return true
            }
            
            hitEntities.append(entity)
            return true
        }
        
        /// Pick the visible node with the highest z position
        return hitEntities.max { firstEntity, secondEntity in
            let firstZPosition = firstEntity.node?.zPosition ?? 0
            let secondZPosition = secondEntity.node?.zPosition ?? 0
            return firstZPosition < secondZPosition
        }
    }
    
    // MARK: Unit Conversion
    
    func meters(fromPoints points: CGFloat) -> Float {
        Float(points / Self.pointsPerMeter)
    }
    
    func points(fromMeters meters: Float) -> CGFloat {
        CGFloat(meters) * Self.pointsPerMeter
    }
    
}
