/**
 
 # Scene
 
 Main SpriteKit scene where presets are loaded.
 
 Achraf Kassioui
 Created 23 May 2026
 Updated 26 May 2026
 
 */
import SpriteKit
//import SwiftBox2D
import box2d

// MARK: Data

struct Entity {
    weak var node: SKNode?
    let bodyID: b2BodyId
}

enum PhysicsCategory {
    static let wall: UInt64 = 0x0001
    static let chain: UInt64 = 0x0002
    static let block: UInt64 = 0x0004
}

enum ZPosition {
    static let background: CGFloat = 0
    static let content: CGFloat = 1
    static let viz: CGFloat = 2
    static let UI: CGFloat = 3
}

struct DragState {
    let pointerEntity: Entity
    let jointID: b2JointId
    var targetPosition: b2Vec2
    let targetRotation: b2Rot
}

struct VisualizedJoint {
    let jointID: b2JointId
    let node: SKShapeNode
    
    /// Draw the line between anchor A and anchor B.
    let drawsAnchorLine: Bool
    
    /// Draw circles at anchor A and anchor B.
    let drawsAnchorPoints: Bool
    
    /// Draw line from each body center to its own anchor.
    let drawsBodyToAnchorLines: Bool
    
    /// Draw local joint frames.
    let drawsFrames: Bool
}

// MARK: Scene

@Observable
class Scene: SKScene, NavigationCameraDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    /// Camera
    let navCamera = NavigationCamera()
    var enableDrag = true
    var cameraZoomPercent = 100
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1 / 60
    private var timeScale: CGFloat = 1 /// 1 = normal speed, 0.5 = slow motion, 2 = fast forward.
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// Box2D
    private static let pointsPerMeter: CGFloat = 150 /// In SpriteKit, 150 points = 1 meter
    private let gravityLength: Float = 10
    //var b2DWorld = B2World()
    var b2WorldId: b2WorldId = b2_nullWorldId
    
    /// Content
    let contentParent = SKNode()
    var indexedEntities: [b2BodyId: Entity] = [:]
    
    /// Joints visualization
    var visualizedJoints: [VisualizedJoint] = []
    
    /// Dragging
    private var activeDrags: [UITouch: DragState] = [:]
    private let shouldMaintainAngle: Bool = true
    
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
        
        addChild(contentParent)
    }
    
    override func willMove(from view: SKView) {
        removeContent()
        removeAllChildren()
    }
    
    deinit {
        removeContent()
        removeAllChildren()
    }
    
    // MARK: Box2D World
    
    func setupBox2D(gravityLength: Float) {
        /// Destroy existing world if one is already running
        if b2World_IsValid(b2WorldId) {
            b2DestroyWorld(b2WorldId)
            b2WorldId = b2_nullWorldId
        }
        
        var worldDef = b2DefaultWorldDef()
        worldDef.gravity = b2Vec2(x: 0, y: gravityLength)
        worldDef.restitutionThreshold = 0
        b2WorldId = b2CreateWorld(&worldDef)
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
    
    // MARK: Cleanup
    
    func removeContent() {
        /// Destroy drag joints first because they reference bodies.
        endDrags(wakeAttached: false)
        
        /// Remove joint visualization nodes.
        for visualizedJoint in visualizedJoints {
            visualizedJoint.node.removeFromParent()
        }
        
        visualizedJoints.removeAll()
        
        /// Remove all SpriteKit nodes and Box2D bodies owned by the scene content.
        for entity in indexedEntities.values {
            removeEntity(entity)
        }
        
        indexedEntities.removeAll()
    }
    
    private func removeEntity(_ entity: Entity) {
        entity.node?.removeFromParent()
        b2DestroyBody(entity.bodyID)
    }
    
    // MARK: Joint Visualization
    
    func addJointVisualization(
        for jointID: b2JointId,
        drawsAnchorLine: Bool,
        drawsAnchorPoints: Bool,
        drawsBodyToAnchorLines: Bool,
        drawsFrames: Bool
    ) {
        /// SpriteKit node used to draw truthful joint geometry.
        let node = SKShapeNode()
        node.strokeColor = .black
        node.fillColor = .black
        node.lineWidth = 3
        node.lineCap = .round
        node.zPosition = ZPosition.viz
        contentParent.addChild(node)
        
        visualizedJoints.append(VisualizedJoint(
            jointID: jointID,
            node: node,
            drawsAnchorLine: drawsAnchorLine,
            drawsAnchorPoints: drawsAnchorPoints,
            drawsBodyToAnchorLines: drawsBodyToAnchorLines,
            drawsFrames: drawsFrames
        ))
    }
    
    func visualizeJoints() {
        for visualizedJoint in visualizedJoints {
            guard b2Joint_IsValid(visualizedJoint.jointID) else { continue }
            
            let bodyIdA = b2Joint_GetBodyA(visualizedJoint.jointID)
            let bodyIdB = b2Joint_GetBodyB(visualizedJoint.jointID)
            
            let bodyTransformA = b2Body_GetTransform(bodyIdA)
            let bodyTransformB = b2Body_GetTransform(bodyIdB)
            
            let localFrameA = b2Joint_GetLocalFrameA(visualizedJoint.jointID)
            let localFrameB = b2Joint_GetLocalFrameB(visualizedJoint.jointID)
            
            /// Joint anchors are body-local, so convert them to world coordinates.
            let anchorA = b2TransformPoint(bodyTransformA, localFrameA.p)
            let anchorB = b2TransformPoint(bodyTransformB, localFrameB.p)
            
            let bodyCenterA = b2Body_GetPosition(bodyIdA)
            let bodyCenterB = b2Body_GetPosition(bodyIdB)
            
            let bodyCenterPointA = CGPoint(
                x: points(fromMeters: bodyCenterA.x),
                y: points(fromMeters: bodyCenterA.y)
            )
            
            let bodyCenterPointB = CGPoint(
                x: points(fromMeters: bodyCenterB.x),
                y: points(fromMeters: bodyCenterB.y)
            )
            
            let anchorPointA = CGPoint(
                x: points(fromMeters: anchorA.x),
                y: points(fromMeters: anchorA.y)
            )
            
            let anchorPointB = CGPoint(
                x: points(fromMeters: anchorB.x),
                y: points(fromMeters: anchorB.y)
            )
            
            let path = CGMutablePath()
            
            if visualizedJoint.drawsAnchorLine {
                /// Draw the constraint error line. For weld joints this may be almost a dot.
                path.move(to: anchorPointA)
                path.addLine(to: anchorPointB)
            }
            
            if visualizedJoint.drawsAnchorPoints {
                /// Draw the two joint anchor points.
                path.addEllipse(in: CGRect(
                    x: anchorPointA.x - 3,
                    y: anchorPointA.y - 3,
                    width: 6,
                    height: 6
                ))
                
                path.addEllipse(in: CGRect(
                    x: anchorPointB.x - 3,
                    y: anchorPointB.y - 3,
                    width: 6,
                    height: 6
                ))
            }
            
            if visualizedJoint.drawsBodyToAnchorLines {
                /// Draw body A center to its local anchor.
                path.move(to: bodyCenterPointA)
                path.addLine(to: anchorPointA)
                
                /// Draw body B center to its local anchor.
                path.move(to: bodyCenterPointB)
                path.addLine(to: anchorPointB)
            }
            
            if visualizedJoint.drawsFrames {
                /// Draw local joint frames to inspect anchor orientation.
                addJointFramePath(
                    to: path,
                    bodyTransform: bodyTransformA,
                    localFrame: localFrameA,
                    axisLength: 14
                )
                
                addJointFramePath(
                    to: path,
                    bodyTransform: bodyTransformB,
                    localFrame: localFrameB,
                    axisLength: 10
                )
            }
            
            visualizedJoint.node.path = path
        }
    }
    
    private func addJointFramePath(
        to path: CGMutablePath,
        bodyTransform: b2Transform,
        localFrame: b2Transform,
        axisLength: CGFloat
    ) {
        /// b2MulTransforms multiplies two transforms: body world transform × local joint frame.
        /// This gives the joint frame expressed in world space.
        let worldFrame = b2MulTransforms(bodyTransform, localFrame)
        
        let origin = CGPoint(
            x: points(fromMeters: worldFrame.p.x),
            y: points(fromMeters: worldFrame.p.y)
        )
        
        let angle = CGFloat(b2Rot_GetAngle(worldFrame.q))
        
        let xAxisEnd = CGPoint(
            x: origin.x + cos(angle) * axisLength,
            y: origin.y + sin(angle) * axisLength
        )
        
        let yAxisEnd = CGPoint(
            x: origin.x + cos(angle + .pi / 2) * axisLength,
            y: origin.y + sin(angle + .pi / 2) * axisLength
        )
        
        path.move(to: origin)
        path.addLine(to: xAxisEnd)
        
        path.move(to: origin)
        path.addLine(to: yAxisEnd)
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
        
        /// Accumulate time from display refresh cycle
        accumulatedTime += deltaTime * timeScale
        
        /// Run code that updates once per rendered frame
        navCamera.lock = !activeDrags.isEmpty
        navCamera.update()
    }
    
    override func didEvaluateActions() {
        navCamera.didEvaluateActions()
    }
    
    override func didSimulatePhysics() {
        /// Check if enough real time has passed to run fixed update
        while accumulatedTime >= fixedTimestep {
            /// Run code on fixed time steps
            fixedUpdate(fixedTimestep)
            accumulatedTime -= fixedTimestep
        }
    }
    
    override func didApplyConstraints() {
        
    }
    
    override func didFinishUpdate() {
        syncRendering()
        visualizeJoints()
    }
    
    // MARK: Fixed Update
    
    private func fixedUpdate(_ fixedTimestep: TimeInterval) {
        /// Move pointer bodies toward their target transforms.
        /// b2Body_SetTargetTransform moves by setting velocity, not teleporting.
        for drag in activeDrags.values {
            b2Body_SetTargetTransform(
                drag.pointerEntity.bodyID,
                b2Transform(p: drag.targetPosition, q: drag.targetRotation), /// p is position, q is rotation
                Float(fixedTimestep),
                true /// Wake from sleep
            )
        }
        
        /// Run the Box2D simulation
        b2World_Step(b2WorldId, Float(fixedTimestep), 4)
    }
    
    // MARK: Sync Rendering
    
    private func syncRendering() {
        /// Get bodies that moved this step.
        /// b2World_GetBodyEvents returns a struct with a C array pointer and a count.
        /// The data is transient: do not store a reference to it.
        let bodyEvents = b2World_GetBodyEvents(b2WorldId)
        
        /// If no body moved, return
        guard let moveEvents = bodyEvents.moveEvents else { return }
        
        /**
         
         bodyEvents has two separate pieces:
         
         - moveEvents: a memory address to the first event in a C array
         - moveCount: how many move events are stored there
         
         The events are stored next to each other in memory.
         Swift does not see this as a normal Array, so we convert moveCount to Int and use it as loop counter.
         
         */
        for index in 0..<Int(bodyEvents.moveCount) {
            let moveEvent = moveEvents[index]
            
            guard let entity = indexedEntities[moveEvent.bodyId] else { continue }
            guard let node = entity.node else { continue }
            
            node.position = CGPoint(
                x: points(fromMeters: moveEvent.transform.p.x),
                y: points(fromMeters: moveEvent.transform.p.y)
            )
            
            node.zRotation = CGFloat(b2Rot_GetAngle(moveEvent.transform.q))
        }
    }
    
    // MARK: Hash
    
    private func stateHashString() -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        
        for entity in indexedEntities.values {
            let bodyPosition = b2Body_GetPosition(entity.bodyID)
            let bodyRotation = b2Body_GetRotation(entity.bodyID)
            
            mixHash(&hash, bodyPosition.x.bitPattern)
            mixHash(&hash, bodyPosition.y.bitPattern)
            mixHash(&hash, b2Rot_GetAngle(bodyRotation).bitPattern)
        }
        
        return String(hash, radix: 16)
    }
    
    private func mixHash(_ hash: inout UInt64, _ value: UInt32) {
        /// FNV-1a style: XOR then multiply by prime. Stable across launches.
        hash ^= UInt64(value)
        hash &*= 1_099_511_628_211
    }
    
    // MARK: Touch Began
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enableDrag else {
            navCamera.stop()
            return
        }
        
        for touch in touches {
            let scenePosition = touch.location(in: self)
            let touchRadius: CGFloat = 11 * navCamera.xScale
            
            /// Find the dynamic Box2D body under this touch
            guard let hitEntity = entity(at: scenePosition, touchRadius: touchRadius) else {
                navCamera.stop()
                continue
            }
            
            /// Convert from SpriteKit to Box2D
            let worldPosition = b2Vec2(
                x: meters(fromPoints: scenePosition.x),
                y: meters(fromPoints: scenePosition.y)
            )
            
            /// Store the dragged body orientation
            let targetRotation = b2Body_GetRotation(hitEntity.bodyID)
            
            /// Create a pointer: kinematic, follow the finger
            let pointerBodyNode = createPointerEntity(
                touchRadius: touchRadius,
                position: worldPosition,
                rotation: targetRotation
            )
            
            /// Define a motor joint
            var jointDef = b2DefaultMotorJointDef()
            jointDef.base.bodyIdA = pointerBodyNode.bodyID
            jointDef.base.bodyIdB = hitEntity.bodyID
            
            /// Box2D joints anchor are expressed in the body local coordinates
            let pointerAnchor = b2Body_GetLocalPoint(pointerBodyNode.bodyID, worldPosition)
            let draggedAnchor = b2Body_GetLocalPoint(hitEntity.bodyID, worldPosition)
            
            jointDef.base.localFrameA.p = pointerAnchor
            jointDef.base.localFrameB.p = draggedAnchor
            
            /// Spring tuning: lower hertz/force is softer, higher is more direct
            jointDef.linearHertz = 7.5
            jointDef.linearDampingRatio = 1
            
            let massData = b2Body_GetMassData(hitEntity.bodyID)
            let gravityStrength = max(b2Length(b2World_GetGravity(b2WorldId)), gravityLength)
            let bodyWeight = max(massData.mass * gravityStrength, 1.0)
            
            jointDef.maxSpringForce = 80 * bodyWeight
            
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
            
            let jointID = b2CreateMotorJoint(b2WorldId, &jointDef)
            
            /// Store drag state
            activeDrags[touch] = DragState(
                pointerEntity: pointerBodyNode,
                jointID: jointID,
                targetPosition: worldPosition,
                targetRotation: targetRotation
            )
            
            /// Visualize joint
            addJointVisualization(
                for: jointID,
                drawsAnchorLine: true,
                drawsAnchorPoints: true,
                drawsBodyToAnchorLines: true,
                drawsFrames: false
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
    
    // MARK: Dragging
    
    private func createPointerEntity(touchRadius: CGFloat, position: b2Vec2, rotation: b2Rot) -> Entity {
        /// Visual pointer
        let pointerNode = SKShapeNode(circleOfRadius: touchRadius)
        pointerNode.fillColor = SKColor.systemCyan.withAlphaComponent(0.5)
        pointerNode.strokeColor = .black
        pointerNode.lineWidth = 3
        pointerNode.position = CGPoint(
            x: points(fromMeters: position.x),
            y: points(fromMeters: position.y)
        )
        pointerNode.zRotation = CGFloat(b2Rot_GetAngle(rotation))
        pointerNode.zPosition = ZPosition.UI
        addChild(pointerNode)
        
        /// Pointer body: kinematic target used by the motor joint
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_kinematicBody
        bodyDef.position = position
        bodyDef.rotation = rotation
        bodyDef.enableSleep = false
        
        /// No shape is needed, the joint only needs a body
        let pointerBodyId = b2CreateBody(b2WorldId, &bodyDef)
        
        let entity = Entity(
            node: pointerNode,
            bodyID: pointerBodyId
        )
        
        indexedEntities[pointerBodyId] = entity
        
        return entity
    }
    
    func endDrags(for touches: Set<UITouch>? = nil, wakeAttached: Bool) {
        for (touch, drag) in activeDrags {
            if let touches, touches.contains(touch) == false { continue }
            
            let pointerBodyId = drag.pointerEntity.bodyID
            
            /// Remove storage first, so no scene code can find this body after destruction.
            indexedEntities[pointerBodyId] = nil
            activeDrags.removeValue(forKey: touch)
            
            /// Remove the joint visualization.
            /// b2JointId is a value type (C struct), so we use == not ===.
            for visualizedJoint in visualizedJoints where visualizedJoint.jointID == drag.jointID {
                visualizedJoint.node.removeFromParent()
            }
            
            visualizedJoints.removeAll { visualizedJoint in
                visualizedJoint.jointID == drag.jointID
            }
            
            // TODO: C API does have a wakeAttached parameter
            /// Destroy joint then body. Order matters: joint references the body.
            b2DestroyJoint(drag.jointID, wakeAttached)
            removeEntity(drag.pointerEntity)
        }
    }
    
    // MARK: Hit Detection
    
    private func entity(at scenePosition: CGPoint, touchRadius: CGFloat) -> Entity? {
        let touchRadiusMeters = meters(fromPoints: touchRadius)
        
        let worldPosition = b2Vec2(
            x: meters(fromPoints: scenePosition.x),
            y: meters(fromPoints: scenePosition.y)
        )
        
        // TODO: single point? misleading
        /// The touch probe is a single point at the origin.
        /// b2MakeOffsetProxy places it at worldPosition with the given radius.
        var probeCenter = b2Vec2(x: 0, y: 0)
        var probe = withUnsafePointer(to: &probeCenter) { probeCenterPointer in
            b2MakeOffsetProxy(
                probeCenterPointer,
                1,
                touchRadiusMeters,
                worldPosition,
                b2Rot_identity /// Zero rotation: the probe has no orientation
            )
        }
        
        var hitEntities: [Entity] = []
        
        /// Ask Box2D which collision shapes overlap the touch footprint.
        /// b2WorldOverlapShape is a local helper that bridges the C callback to a Swift closure.
        b2WorldOverlapShape(b2WorldId, &probe, b2DefaultQueryFilter()) { shapeId in
            let bodyId = b2Shape_GetBody(shapeId)
            
            guard let entity = self.indexedEntities[bodyId] else {
                return true
            }
            
            guard b2Body_GetType(entity.bodyID) == b2_dynamicBody else {
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

/**
 
 SpriteKit was running slow on iPhone 13 with iOS 26.5.
 I noticed performance dropped when number of nodes was low.
 Made this function to add nodes.
 Results: didn't help. However using sprite nodes instead of shape nodes in presets did help.
 It's still a bug that affects iPhone 13 (A15 chip). Shapes run well on A17 Pro and M1 Pro.
 
 Updated: 26 May 2026
 
 */
extension Scene {
    
    func antiJerk() {
        let nodeCount = 1000
        let columns = 40
        let spacing: CGFloat = 28
        let nodeSize = CGSize(width: 18, height: 18)
        
        let rotateAction = SKAction.repeatForever(
            SKAction.rotate(byAngle: .pi * 2, duration: 1)
        )
        
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: nodeSize.width,
            height: nodeSize.height,
            cornerRadius: 3
        )
        
        for index in 0..<nodeCount {
            let column = index % columns
            let row = index / columns
            
            let node = SKSpriteNode(texture: texture)
            node.zPosition = ZPosition.background
            node.position = CGPoint(
                x: (CGFloat(column) - CGFloat(columns - 1) / 2) * spacing,
                y: CGFloat(row) * spacing
            )
            
            addChild(node)
            node.run(rotateAction)
        }
    }
    
}
