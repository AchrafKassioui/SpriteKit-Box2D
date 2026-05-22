/**
 
 # Drag
 
 A scene to test dragging physical nodes with Box2D.
 A motor joint is created between a pointer entity and the dragged entity.
 It seems the motor joint has replaced the mouse joint for the drag/manipulation scenario.
 
 Achraf Kassioui
 Created 20 May 2026
 Updated 21 May 2026
 
 */
import SpriteKit
import SwiftUI
import SwiftBox2D
import Observation

// MARK: View

struct DragView: View {
    @State var scene = DragScene()
    
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
                    /// Camera
                    ToggleButton(
                        isOn: false,
                        onText: "Camera",
                        offText: "Camera",
                        onSystemImage: "viewfinder",
                        offSystemImage: "viewfinder",
                        action: {
                            scene.navCamera.reset()
                        }
                    )
                    
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
                                       
                    /// Debug
                    ToggleButton(
                        isOn: false,
                        onText: "",
                        offText: "",
                        onSystemImage: "stethoscope",
                        offSystemImage: "stethoscope",
                        action: {
                            scene.debugPhysics.toggle()
                        }
                    )
                    
                    Spacer()
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
    DragView()
}

// MARK: Scene

@Observable
class DragScene: SKScene {
    
    // MARK: Properties
    
    /// Camera
    let navCamera = NavigationCamera()
    var cameraDragOnly = false
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1/60
    private let physicsSpeed: CGFloat = 1
    private var accumulatedTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    
    /// Box2D
    private static let pointsPerMeter: CGFloat = 150 /// Same scale as SpriteKit, where 150 points = 1 meter
    private let gravityLength: Float = 10
    private let b2DWorld = B2World()
    private let debugRenderer = Box2DDebugRenderer(pointsPerMeter: pointsPerMeter)
    var debugPhysics: Bool = false
    
    /// Entities
    private struct Entity {
        weak var node: SKNode?
        let body: B2Body
    }
    
    private var entities: [Entity] = []
    
    /// Dragging
    private struct DragState {
        let pointerEntity: Entity
        let joint: B2MotorJoint
        let jointViz: SKShapeNode
        var targetPosition: B2Vec2
        let targetRotation: B2Rot
    }
    private var activeDrags: [UITouch: DragState] = [:]
    private let shouldMaintainRotation = true
    
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
        cleanup()
    }
    
    // MARK: Cleanup
    
    deinit {
        cleanup()
    }
    
    private func cleanup() {
        endDrags(wakeAttached: false)
        
        for entity in entities {
            removeEntity(entity)
        }
        
        self.removeAllChildren()
    }
    
    private func removeEntity(_ entity: Entity) {
        entity.node?.removeFromParent()
        entity.body.destroy()
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
            }
        ])
        action.timingMode = .linear
        run(action)
    }
    
    // MARK: Content
    
    func createContent() {
        guard let view = self.view else { return }
        removeContent()
        createWalls(view: view)
        createBlocks(view: view)
    }
    
    private func removeContent() {
        /// Destroy drag joints first because they reference bodies.
        endDrags(wakeAttached: false)
        
        /// Remove all SpriteKit nodes and Box2D bodies owned by the scene content.
        for entity in entities {
            removeEntity(entity)
        }
        
        entities.removeAll()
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
        
        self.camera = navCamera
        addChild(navCamera)
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
        pointerNode.zPosition = 1000
        addChild(pointerNode)
        
        /// Pointer body: kinematic target used by the motor joint
        var bodyDef = b2BodyDef.default()
        bodyDef.type = .b2KinematicBody
        bodyDef.position = position
        bodyDef.rotation = rotation
        bodyDef.enableSleep = false
        
        /// No shape is needed, the joint only needs a body
        let pointerBody = b2DWorld.createBody(bodyDef)
        
        let pointerBodyNode = Entity(
            node: pointerNode,
            body: pointerBody,
        )
        
        entities.append(pointerBodyNode)
        
        return pointerBodyNode
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
            
            /// Visual node
            let node = SKShapeNode(rectOf: size)
            node.fillColor = .gray
            node.strokeColor = .black
            node.lineWidth = 2
            node.position = position
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
            
            /// Static container parts are simple rectangle collision shapes.
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: size.width / 2),
                halfHeight: meters(fromPoints: size.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            entities.append(Entity(node: node, body: body))
        }
    }
    
    // MARK: Blocks
    
    private func createBlocks(view: SKView, useCircles: Bool = false) {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let padding: CGFloat = 15
        let innerHeight = safe.height - padding * 2
        let groundTopY = -innerHeight / 2
        let gapAboveGround: CGFloat = 400
        
        let columns = 6
        let rows = 100
        let cellSize: CGFloat = 80
        let blockSize = CGSize(width: 75, height: 75)
        let cornerRadius: CGFloat = 12
        
        for row in 0..<rows {
            for column in 0..<columns {
                let blockX = (CGFloat(column) - CGFloat(columns - 1) / 2) * cellSize
                let blockY = groundTopY + gapAboveGround + (CGFloat(row) + 0.5) * cellSize
                let position = CGPoint(x: blockX, y: blockY)
                
                /// Pick one visual/collision shape for this block.
                let isCircle = true
                
                /// SpriteKit node
                let texture = ResourceCache.texture(
                    isRectangle: !isCircle,
                    width: blockSize.width,
                    height: blockSize.height
                )
                
                let node = SKSpriteNode(texture: texture, size: blockSize)
                node.colorBlendFactor = 1
                node.color = .systemYellow
                node.position = position
                addChild(node)
                
                /// Box2D body
                var bodyDef = b2BodyDef.default()
                bodyDef.type = .b2DynamicBody
                bodyDef.position = B2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                bodyDef.linearDamping = 0
                bodyDef.angularDamping = 0
                bodyDef.enableSleep = false
                
                let body = b2DWorld.createBody(bodyDef)
                
                /// Box2D material
                var shapeDef = b2ShapeDef.default()
                shapeDef.density = 2
                shapeDef.material.friction = 0
                shapeDef.material.restitution = 1
                
                if isCircle {
                    /// Circle collision shape
                    let circle = B2Circle(
                        center: B2Vec2(x: 0, y: 0),
                        radius: meters(fromPoints: blockSize.width / 2)
                    )
                    
                    body.createShape(circle, shapeDef: shapeDef)
                } else {
                    let clampedCornerRadius = min(cornerRadius, blockSize.width / 2, blockSize.height / 2)
                    let roundedRadius = meters(fromPoints: clampedCornerRadius)
                    
                    let innerHalfWidth = max(
                        0.001,
                        meters(fromPoints: blockSize.width / 2 - clampedCornerRadius)
                    )
                    
                    let innerHalfHeight = max(
                        0.001,
                        meters(fromPoints: blockSize.height / 2 - clampedCornerRadius)
                    )
                    
                    /// Rounded rectangle collision shape
                    let polygon = b2MakeRoundedBox(
                        innerHalfWidth,
                        innerHalfHeight,
                        roundedRadius
                    )
                    
                    body.createShape(polygon, shapeDef: shapeDef)
                }
                
                entities.append(Entity(node: node, body: body))
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
        
        /// Run systems that update once per rendered frame
        update(deltaTime: deltaTime)
        
        ///  Convert current time into fixed time step
        accumulatedTime += deltaTime * physicsSpeed
        
        while accumulatedTime >= fixedTimestep {
            /// Run systems on fixed time steps
            fixedUpdate(deltaTime: fixedTimestep)
            
            accumulatedTime -= fixedTimestep
        }
    }
    
    override func didEvaluateActions() {
        navCamera.didEvaluateActions()
    }
    
    override func didSimulatePhysics() {
        /// Move pointer
        for drag in activeDrags.values {
            drag.pointerEntity.body.setTargetTransform( /// move by setting velocity, not teleport
                B2Transform(p: drag.targetPosition, q: drag.targetRotation), /// p is position, q is rotation
                1.0 / 60.0,
                true /// Wake from sleep
            )
        }
        
        /// Simulate
        b2DWorld.step(1.0 / 60.0, subSteps: 4)
        
        /// Retrieve simulation results
        for entity in entities {
            guard let node = entity.node else { continue }
            
            let bodyPosition = entity.body.getPosition()
            let bodyRotation = entity.body.getRotation()
            
            node.position = CGPoint(
                x: points(fromMeters: bodyPosition.x),
                y: points(fromMeters: bodyPosition.y)
            )
            node.zRotation = CGFloat(bodyRotation.angle)
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
        
        /// Box2D debug draw
        if debugPhysics {
            debugRenderer.draw(world: b2DWorld)
        } else {
            debugRenderer.clear()
        }
    }
    
    private func update(deltaTime: TimeInterval) {
        navCamera.lock = !activeDrags.isEmpty
        navCamera.update()
    }
    
    // MARK: Fixed Update
    
    private func fixedUpdate(deltaTime: TimeInterval) {
        
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
            
            /// Spring tuning: lower hertz/force feels softer, higher feels more direct.
            jointDef.linearHertz = 7.5
            jointDef.linearDampingRatio = 1
            
            let massData = draggedBodyNode.body.massData
            let gravityStrength = max(b2DWorld.gravity.length, gravityLength)
            let bodyWeight = max(massData.mass * gravityStrength, 1.0)
            
            jointDef.maxSpringForce = 80 * bodyWeight
            
            if massData.mass > 0.0 {
                let lever = sqrt(massData.rotationalInertia / massData.mass)
                
                if shouldMaintainRotation {
                    /// Angular spring keeps the dragged body close to its starting rotation.
                    jointDef.angularHertz = 10
                    jointDef.angularDampingRatio = 1.0
                    jointDef.maxSpringTorque = 500.0 * lever * bodyWeight
                } else {
                    /// Angular velocity torque acts like mild spin friction while allowing rotation.
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
            jointVizNode.zPosition = 10
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
            
            drag.joint.destroy(wakeAttached: wakeAttached)
            drag.jointViz.removeFromParent()
            removeEntity(drag.pointerEntity)
            entities.removeAll { $0.body.id == drag.pointerEntity.body.id }
            activeDrags.removeValue(forKey: touch)
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
        
        /// The touch probe is a small circle placed at the touch position.
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
        
        /// Ask Box2D which collision shapes overlap the touch footprint.
        b2DWorld.overlapShape(probe, filter: .default()) { shape in
            let bodyId = shape.getBody()
            
            guard let entity = entities.first(where: { $0.body.id == bodyId }) else {
                return true
            }
            
            guard entity.body.type == .b2DynamicBody else {
                return true
            }
            
            hitEntities.append(entity)
            return true
        }
        
        /// Pick the visible node with the highest SpriteKit z position.
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
