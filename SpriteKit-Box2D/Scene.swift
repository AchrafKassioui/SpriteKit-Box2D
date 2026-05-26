/**
 
 # Scene
 
 Main SpriteKit scene where content is added.
 
 Achraf Kassioui
 Created 23 May 2026
 Updated 24 May 2026
 
 */
import SpriteKit
import SwiftBox2D

// MARK: Data

struct Entity {
    weak var node: SKNode?
    let body: B2Body
}

enum PhysicsCategory {
    static let wall: UInt64 = 0x0001
    static let chain: UInt64 = 0x0002
    static let block: UInt64 = 0x0004
}

/// Layers
enum ZPosition {
    static let background: CGFloat = 0
    static let content: CGFloat = 1
    static let viz: CGFloat = 2
    static let UI: CGFloat = 3
}

// MARK: Scene

@Observable
class Scene: SKScene, NavigationCameraDelegate, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    /// Camera
    let navCamera = NavigationCamera()
    var enableDrag = false
    var cameraZoomPercent = 100
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1 / 60
    private var timeScale: CGFloat = 1 /// 1 = normal speed, 0.5 = slow motion, 2 = fast forward.
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// Box2D
    private static let pointsPerMeter: CGFloat = 150 /// In SpriteKit, 150 points = 1 meter
    private let gravityLength: Float = 10
    let b2DWorld = B2World()
    
    /// Entities
    var entities: [B2BodyId: Entity] = [:]
    
    /// Joints viz
    struct WeldJoint {
        let joint: B2WeldJoint
        let bodyA: B2Body
        let bodyB: B2Body
        let jointViz: SKShapeNode
    }
    var weldJoints: [WeldJoint] = []
    
    /// Dragging
    private struct DragState {
        let pointerEntity: Entity
        let joint: B2MotorJoint
        let jointViz: SKShapeNode
        var targetPosition: B2Vec2
        let targetRotation: B2Rot
    }
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
        
        /// Box2D
        setupBox2D()
        
        //antiJerk()
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
    
    // MARK: Cleanup
    
    func removeContent() {
        /// Destroy drag joints first because they reference bodies.
        endDrags(wakeAttached: false)
        
        /// Destroy weld joints before destroying their connected bodies.
        for weldJoint in weldJoints {
            weldJoint.joint.destroy(wakeAttached: false)
            weldJoint.jointViz.removeFromParent()
        }
        
        weldJoints.removeAll()
        
        /// Remove all SpriteKit nodes and Box2D bodies owned by the current preset.
        let removedEntities = Array(entities.values)
        entities.removeAll()
        
        for entity in removedEntities {
            removeEntity(entity)
        }
    }
    
    private func removeEntity(_ entity: Entity) {
        entity.node?.removeFromParent()
        entity.body.destroy()
    }
    
    // MARK: Ground
    
    func createGround() {
        let size = CGSize(width: 2000, height: 15)
        let position = CGPoint(x: 0, y: -300)
        
        /// Visual node
        let node = SKShapeNode(rectOf: size)
        node.fillColor = .gray
        node.strokeColor = .black
        node.position = position
        node.zPosition = ZPosition.content
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
        
        /// Box2D box dimensions are half extents in meters.
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        entities[body.id] = Entity(node: node, body: body)
    }
    
    // MARK: Sync Rendering
    
    private func syncRendering() {
        /// Get bodies that moved
        let bodyEvents = b2DWorld.getBodyEvents()
        
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
            
            guard let entity = entities[moveEvent.bodyId] else { continue }
            guard let node = entity.node else { continue }
            
            node.position = CGPoint(
                x: points(fromMeters: moveEvent.transform.p.x),
                y: points(fromMeters: moveEvent.transform.p.y)
            )
            
            node.zRotation = CGFloat(moveEvent.transform.q.angle)
            
            if moveEvent.fellAsleep {
                /// This body is sleeping
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
        
        /// Run the Box2D simulation
        b2DWorld.step(Float(fixedTimestep), subSteps: 4)
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
    
    // MARK: Dragging
    
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
