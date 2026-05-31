/**
 
 # Dragging Scene
 
 A scene that implements dragging with physics in Box2D v3.
 
 - On touchesBegan, a kinematic pointer body of some size is created.
 - Hit detection is made with an overlap shape of that size.
 - A motor joint is created between the pointer body and the touched entity.
 - TouchesMoved sets the target position of the pointer.
 - Fixed update moves the pointer to the target position using velocity.
 - The joint pull/pushes the dragged entity.
 
## Notes
 
 - With Box2D version 3, it seems motor joint has replaced the mouse joint as the go-to implementation for physics-based dragging.
 - Box2D's perfomance in release build are much better than in debug build.
 
 Achraf Kassioui
 Created 20 May 2026
 Updated 31 May 2026
 
 */
import SpriteKit
import SwiftUI
import box2d
import Observation

// MARK: View

struct DragView: View {
    @State var scene = DraggingScene()
    
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
                        onText: "100%",
                        offText: ("\(scene.cameraZoomPercent)%"),
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
                        isOn: scene.isDraggingEnabled,
                        onText: "Dragging Is Enabled",
                        offText: "Dragging Is Disabled",
                        onSystemImage: "hand.draw.fill",
                        offSystemImage: "hand.raised.fill",
                        action: {
                            scene.isDraggingEnabled.toggle()
                            if scene.isDraggingEnabled {
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
class DraggingScene: SKScene, NavigationCameraDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    /// Camera
    let navCamera = NavigationCamera()
    var isDraggingEnabled = true
    var cameraZoomPercent = 100
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1/60
    private var physicsSpeed: CGFloat = 1
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// Box2D
    private static let pointsPerMeter: CGFloat = 150 /// In SpriteKit, 150 points = 1 meter
    private let gravityLength: Float = 10
    private var b2WorldId: b2WorldId = b2_nullWorldId
    //private let debugRenderer = Box2DDebugRenderer(pointsPerMeter: pointsPerMeter)
    var debugPhysics: Bool = false /// Warning, if there are too many nodes, app may crash or framerate may tank.
    
    /// Entities
    private struct Entity {
        weak var node: SKNode?
        let bodyId: b2BodyId
    }
    
    private var entities: [Entity] = []
    
    /// Dragging
    private struct DragState {
        let pointerEntity: Entity
        let jointID: b2JointId
        let jointViz: SKShapeNode
        var targetPosition: b2Vec2
        let targetRotation: b2Rot
    }
    private var activeDrags: [UITouch: DragState] = [:]
    private let shouldMaintainAngle = true
    
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
        //addChild(debugRenderer.node)
        
        /// Content
        createContent()
    }
    
    override func willMove(from view: SKView) {
        cleanup()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: Cleanup
    
    private func cleanup() {
        endDrags(wakeAttached: false)
        
        for entity in entities {
            entity.node?.removeFromParent()
        }
        
        entities.removeAll()
        removeAllChildren()
        
        /// The world owns all Box2D bodies, shapes, contacts, and joints.
        if b2World_IsValid(b2WorldId) {
            b2DestroyWorld(b2WorldId)
            b2WorldId = b2_nullWorldId
        }
    }
    
    private func removeEntity(_ entity: Entity) {
        entity.node?.removeFromParent()
        if b2Body_IsValid(entity.bodyId) {
            b2DestroyBody(entity.bodyId)
        }
    }
    
    // MARK: Camera
    
    func setupCamera(view: UIView) {
        navCamera.delegate = self
        navCamera.gestureRecognizerDelegate = self
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
    func cameraDidMove(to position: CGPoint) {
        
    }
    
    func cameraDidRotate(to angle: CGFloat) {
        
    }
    
    func cameraDidScale(to scale: CGPoint) {
        /// Scale is inverse zoom
        cameraZoomPercent = Int((1 / scale.x * 100).rounded())
    }
    
    // MARK: Box2D World
    
    private func setupBox2D() {
        /// Destroy the previous world if this scene is being reused.
        if b2World_IsValid(b2WorldId) {
            b2DestroyWorld(b2WorldId)
            b2WorldId = b2_nullWorldId
        }
        
        var worldDef = b2DefaultWorldDef()
        worldDef.gravity = b2Vec2(x: 0, y: 0)
        worldDef.restitutionThreshold = 0
        
        b2WorldId = b2CreateWorld(&worldDef)
        
        let action = SKAction.sequence([
            .wait(forDuration: 2),
            .run { [weak self] in
                guard let self else { return }
                
                b2World_SetGravity(b2WorldId, b2Vec2(x: 0, y: -gravityLength))
                
                /// Keep default sleeping enabled, but wake existing bodies once when gravity starts.
                for entity in entities {
                    b2Body_SetAwake(entity.bodyId, true)
                }
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
    
    // MARK: Walls
    
    private func createWalls(view: SKView) {
        let thickness: CGFloat = 15
        let baseWidth: CGFloat = 1000
        let sideHeight: CGFloat = 10000
        
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
            
            /// Box2D body.
            var bodyDef = b2DefaultBodyDef()
            bodyDef.type = b2_staticBody
            bodyDef.position = b2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            
            let bodyId = b2CreateBody(b2WorldId, &bodyDef)
            
            /// Box2D material.
            var shapeDef = b2DefaultShapeDef()
            shapeDef.density = 0
            
            /// Static container parts are simple rectangle collision shapes.
            var polygon = b2MakeBox(
                meters(fromPoints: size.width / 2),
                meters(fromPoints: size.height / 2)
            )
            
            b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
            
            entities.append(Entity(node: node, bodyId: bodyId))
        }
    }
    
    // MARK: Blocks
    
    private func createBlocks(view: SKView, useCircles: Bool = false) {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let padding: CGFloat = 15
        let innerHeight = safe.height - padding * 2
        let groundTopY = -innerHeight / 2
        let gapAboveGround: CGFloat = 400
        
        let columns = 4
        let rows = 4
        let cellSize: CGFloat = 80
        let blockSize = CGSize(width: 75, height: 75)
        let cornerRadius: CGFloat = 12
        let colors: [SKColor] = [.systemOrange, .systemYellow, .systemTeal, .systemRed, .white, .systemGray]
        
        for row in 0..<rows {
            for column in 0..<columns {
                let blockX = (CGFloat(column) - CGFloat(columns - 1) / 2) * cellSize
                let blockY = groundTopY + gapAboveGround + (CGFloat(row) + 0.5) * cellSize
                let position = CGPoint(x: blockX, y: blockY)
                
                let isCircle = true
                
                /// SpriteKit node
                let texture = ResourceCache.texture(
                    isRectangle: !isCircle,
                    width: blockSize.width,
                    height: blockSize.height,
                    cornerRadius: 9,
                )
                
                let node = SKSpriteNode(texture: texture, size: blockSize)
                node.colorBlendFactor = 1
                node.color = colors.randomElement() ?? .systemYellow
                node.position = position
                addChild(node)
                
                /// Box2D body.
                var bodyDef = b2DefaultBodyDef()
                bodyDef.type = b2_dynamicBody
                bodyDef.position = b2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                
                /// Tuning to prevent bodies from flying too far on drag release, but avoid gravity damping.
                /// Tweak to taste.
                bodyDef.linearDamping = 6
                bodyDef.angularDamping = 2
                bodyDef.gravityScale = 10
                
                let bodyId = b2CreateBody(b2WorldId, &bodyDef)
                
                /// Box2D material.
                var shapeDef = b2DefaultShapeDef()
                shapeDef.density = 1
                shapeDef.material.friction = 0.5
                shapeDef.material.restitution = 0.2
                
                if isCircle {
                    /// Circle collision shape.
                    var circle = b2Circle(
                        center: b2Vec2(x: 0, y: 0),
                        radius: meters(fromPoints: blockSize.width / 2)
                    )
                    
                    b2CreateCircleShape(bodyId, &shapeDef, &circle)
                } else {
                    let clampedCornerRadius = min(
                        cornerRadius,
                        blockSize.width / 2,
                        blockSize.height / 2
                    )
                    
                    let roundedRadius = meters(fromPoints: clampedCornerRadius)
                    let innerHalfWidth = max(0.001, meters(fromPoints: blockSize.width / 2 - clampedCornerRadius))
                    let innerHalfHeight = max(0.001, meters(fromPoints: blockSize.height / 2 - clampedCornerRadius))
                    
                    /// Rounded rectangle collision shape.
                    /// Box2D rounded boxes are a core box inflated by radius, so subtract the radius to keep the total size true to the texture.
                    var roundedPolygon = b2MakeRoundedBox(
                        innerHalfWidth,
                        innerHalfHeight,
                        roundedRadius
                    )
                    
                    b2CreatePolygonShape(bodyId, &shapeDef, &roundedPolygon)
                }
                
                entities.append(Entity(node: node, bodyId: bodyId))
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
    
    private func fixedUpdate(_ fixedTimestep: TimeInterval) {
        /// Move pointer bodies toward their target transforms.
        /// b2Body_SetTargetTransform moves by setting velocity, not teleporting.
        for drag in activeDrags.values {
            b2Body_SetTargetTransform(
                drag.pointerEntity.bodyId,
                b2Transform(p: drag.targetPosition, q: drag.targetRotation), /// p is position, q is rotation
                Float(fixedTimestep),
                true /// Wake from sleep
            )
        }
        
        /// Step Box2D with the fixed timestep.
        b2World_Step(b2WorldId, Float(fixedTimestep), 4)
    }
    
    override func didApplyConstraints() {
        
    }
    
    override func didFinishUpdate() {
        /// Retrieve simulation results.
        for entity in entities {
            guard let node = entity.node else { continue }
            guard b2Body_IsValid(entity.bodyId) else { continue }
            
            let bodyPosition = b2Body_GetPosition(entity.bodyId)
            let bodyRotation = b2Body_GetRotation(entity.bodyId)
            
            node.position = CGPoint(
                x: points(fromMeters: bodyPosition.x),
                y: points(fromMeters: bodyPosition.y)
            )
            
            node.zRotation = CGFloat(b2Rot_GetAngle(bodyRotation))
        }
        
        /// Draw dragging joints.
        for drag in activeDrags.values {
            guard b2Joint_IsValid(drag.jointID) else { continue }
            
            let pointerBodyID = b2Joint_GetBodyA(drag.jointID)
            let draggedBodyID = b2Joint_GetBodyB(drag.jointID)
            
            let pointerTransform = b2Body_GetTransform(pointerBodyID)
            let draggedTransform = b2Body_GetTransform(draggedBodyID)
            
            let localFrameA = b2Joint_GetLocalFrameA(drag.jointID)
            let localFrameB = b2Joint_GetLocalFrameB(drag.jointID)
            
            /// Joint anchors are body-local, so convert them to world coordinates.
            let worldPointA = b2TransformPoint(pointerTransform, localFrameA.p)
            let worldPointB = b2TransformPoint(draggedTransform, localFrameB.p)
            
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
            
            /// Draw the dragged-body anchor at body B.
            path.addEllipse(in: CGRect(
                x: pointB.x - 8,
                y: pointB.y - 8,
                width: 16,
                height: 16
            ))
            
            drag.jointViz.path = path
        }
        
        /// Box2D debug draw
//        if debugPhysics {
//            debugRenderer.draw(world: b2DWorld)
//        } else {
//            debugRenderer.clear()
//        }
    }
    
    // MARK: Touch Began
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingEnabled else {
            navCamera.stop()
            return
        }
        
        for touch in touches {
            let scenePosition = touch.location(in: self)
            let touchRadius: CGFloat = 11
            
            /// Find the dynamic Box2D body under this touch.
            guard let draggedEntity = entity(at: scenePosition, touchRadius: touchRadius) else {
                navCamera.stop()
                continue
            }
            
            /// Convert from SpriteKit points to Box2D meters.
            let worldPosition = b2Vec2(
                x: meters(fromPoints: scenePosition.x),
                y: meters(fromPoints: scenePosition.y)
            )
            
            /// Store the dragged body orientation at the start of the drag.
            let targetRotation = b2Body_GetRotation(draggedEntity.bodyId)
            
            /// Create a kinematic pointer body that follows the finger.
            let pointerEntity = createPointerEntity(
                touchRadius: touchRadius,
                position: worldPosition,
                rotation: targetRotation
            )
            
            /// Define a motor joint between the pointer body and the dragged body.
            var jointDef = b2DefaultMotorJointDef()
            jointDef.base.bodyIdA = pointerEntity.bodyId
            jointDef.base.bodyIdB = draggedEntity.bodyId
            
            /// Box2D joint anchors are expressed in each body's local coordinates.
            jointDef.base.localFrameA.p = b2Body_GetLocalPoint(pointerEntity.bodyId, worldPosition)
            jointDef.base.localFrameB.p = b2Body_GetLocalPoint(draggedEntity.bodyId, worldPosition)
            
            /// Spring/drag tuning.
            jointDef.linearHertz = 7.5
            jointDef.linearDampingRatio = 1
            
            let massData = b2Body_GetMassData(draggedEntity.bodyId)
            let gravityStrength = max(b2Length(b2World_GetGravity(b2WorldId)), gravityLength)
            let bodyWeight = max(massData.mass * gravityStrength, 1.0)
            
            jointDef.maxSpringForce = 80 * bodyWeight
            
            if massData.mass > 0.0 {
                let lever = sqrt(massData.rotationalInertia / massData.mass)
                
                if shouldMaintainAngle {
                    /// Angular spring keeps the dragged body close to its starting rotation.
                    jointDef.angularHertz = 10
                    jointDef.angularDampingRatio = 1
                    jointDef.maxSpringTorque = 50_000 * lever * bodyWeight
                } else {
                    /// Angular velocity torque acts like mild spin friction while allowing rotation.
                    jointDef.maxVelocityTorque = 0.25 * lever * bodyWeight
                    jointDef.maxSpringTorque = 0
                }
            }
            
            let jointID = b2CreateMotorJoint(b2WorldId, &jointDef)
            
            /// Visualize the joint.
            let jointVizNode = SKShapeNode()
            jointVizNode.strokeColor = .black
            jointVizNode.fillColor = .black
            jointVizNode.lineWidth = 3
            jointVizNode.lineCap = .round
            jointVizNode.zPosition = 10
            addChild(jointVizNode)
            
            /// Store drag state.
            activeDrags[touch] = DragState(
                pointerEntity: pointerEntity,
                jointID: jointID,
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
            drag.targetPosition = b2Vec2(
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
    
    // MARK: Pointer
    
    private func createPointerEntity(touchRadius: CGFloat, position: b2Vec2, rotation: b2Rot) -> Entity {
        /// Visual pointer.
        let pointerNode = SKShapeNode(circleOfRadius: touchRadius)
        pointerNode.fillColor = SKColor.systemCyan.withAlphaComponent(0.5)
        pointerNode.strokeColor = .black
        pointerNode.lineWidth = 3
        pointerNode.position = CGPoint(
            x: points(fromMeters: position.x),
            y: points(fromMeters: position.y)
        )
        pointerNode.zRotation = CGFloat(b2Rot_GetAngle(rotation))
        pointerNode.zPosition = 1000
        addChild(pointerNode)
        
        /// Pointer body: kinematic target used by the motor joint.
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_kinematicBody
        bodyDef.position = position
        bodyDef.rotation = rotation
        bodyDef.enableSleep = false
        
        /// No shape is needed. The joint only needs a body.
        let pointerBodyId = b2CreateBody(b2WorldId, &bodyDef)
        
        let pointerEntity = Entity(
            node: pointerNode,
            bodyId: pointerBodyId
        )
        
        entities.append(pointerEntity)
        
        return pointerEntity
    }
    
    // MARK: End Drag
    
    func endDrags(for touches: Set<UITouch>? = nil, wakeAttached: Bool) {
        for (touch, drag) in activeDrags {
            if let touches, touches.contains(touch) == false { continue }
            
            /// Destroy joint before pointer body. The joint references both bodies.
            if b2Joint_IsValid(drag.jointID) {
                b2DestroyJoint(drag.jointID, wakeAttached)
            }
            
            drag.jointViz.removeFromParent()
            removeEntity(drag.pointerEntity)
            
            entities.removeAll { entity in
                //isSameBodyID(entity.bodyID, drag.pointerEntity.bodyID)
                entity.bodyId == drag.pointerEntity.bodyId
            }
            
            activeDrags.removeValue(forKey: touch)
        }
    }
    
    // MARK: Hit Detection
    
    private func entity(at scenePosition: CGPoint, touchRadius: CGFloat) -> Entity? {
        let touchRadiusMeters = meters(fromPoints: touchRadius)
        
        let worldPosition = b2Vec2(
            x: meters(fromPoints: scenePosition.x),
            y: meters(fromPoints: scenePosition.y)
        )
        
        var probeCenter = b2Vec2(x: 0, y: 0)
        
        /// The touch probe is a small circle placed at the touch position.
        var probe = withUnsafePointer(to: &probeCenter) { probeCenterPointer in
            b2MakeOffsetProxy(
                probeCenterPointer,
                1,
                touchRadiusMeters,
                worldPosition,
                b2Rot_identity
            )
        }
        
        var hitEntities: [Entity] = []
        
        /// Ask Box2D which collision shapes overlap the touch footprint.
        b2WorldOverlapShape(b2WorldId, proxy: &probe, filter: b2DefaultQueryFilter()) { shapeID in
            let bodyID = b2Shape_GetBody(shapeID)
            
            guard let entity = entities.first(where: { $0.bodyId == bodyID }) else {
                return true
            }
            
            guard b2Body_GetType(entity.bodyId) == b2_dynamicBody else {
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
