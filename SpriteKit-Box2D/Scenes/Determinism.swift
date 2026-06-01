/**
 
 # Determinism Scene
 
 A scene to test Box2D determinism.
 
 ## Setup
 
 - A new Box2D world is created each time content is reset.
 - The same bodies are recreated in the same order.
 - The simulation runs for a fixed number of physics steps, then pauses.
 - After that fixed step count, a hash of all body transforms is generated.
 - Identical hash between runs = identical transform state = identical simulation outcome.
 
 ## Findings
 
 Box2D is deterministic, provided:
 - A new physics world is created for each replay / reset.
 - The same world settings, fixed timestep, and substep count are used.
 - Bodies are created in the same order.
 - The same initial positions, rotations, velocities, and forces / impulses are used.
 
 Creation order is important and part of the simulation input.
 
 ## Creation Order
 
 The transient body test explores creation order further.
 
 Test A:
 - A body is created and deleted during the simulation, after all boxes have been created.
 - I compare the hash of the boxes with and without that transient body.
 - I get the same hash.
 
 Test B:
 - A body is created after he ground and before the boxes.
 - The transient body is configured to not collide with the boxes.
 - I compare the hash of the boxes with and without that transient body.
 - I get the same hash.
 
 Test C:
 - A body is created inside the box creation loop, between two box bodies.
 - I test different insertion indexes in the box creation order.
 - The transient body is configured to not collide with the boxes.
 - I compare the hash of the boxes with and without that transient body.
 - I get the same hash.
 
 In these tests, the transient body did not change the final hash of the boxes no matter when it was created and deleted.
 
 ## Links
 
 https://box2d.org/posts/2024/08/determinism/
 https://gafferongames.com/post/fix_your_timestep/
 
 Achraf Kassioui
 Created 25 May 2026
 Updated 30 May 2026
 
 */
import SwiftUI
import SpriteKit
import Box2D

// MARK: View

struct DeterminismView: View {
    var body: some View {
        ZStack {
            SpriteView(
                scene: DeterminismScene(),
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
    DeterminismView()
}

// MARK: Scene

class DeterminismScene: SKScene {
    
    // MARK: Properties
    
    /// Custom camera for inspecting the scene
    let navCamera = NavigationCamera()
    
    /// Box2D world id.
    private var b2WorldId: b2WorldId = b2_nullWorldId
    
    /// How many SpriteKit screen points is one meter in the simulation
    static let pointsPerMeter: CGFloat = 150
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1 / 60
    private var timeScale: CGFloat = 1 /// 1 = normal speed, 0.5 = slow motion, 2 = fast forward.
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// Determinism test
    private let testFixedStepLimit: Int = 150
    private var testFixedStepIndex: Int = 0
    private var isTestPaused: Bool = false
    private var shouldRestartSimulation: Bool = false
    private var previousHash: String = "..."
    
    /// Transient body
    private let shouldCreateTransientBodyDuringSimulation = false
    private let shouldCreateTransientBodyBeforeBoxes = false
    private let shouldCreateTransientBodyInsideBoxes = true
        
    private let transientCreateStepIndex = 30
    private let transientDestroyStepIndex = 120
    private let transientBodyBoxCreationIndex = 20
    private var transientEntity: Entity?
    
    /// An object that references a visual node and a Box2D body
    private struct Entity {
        weak var node: SKNode?
        let bodyId: b2BodyId
    }
    
    private var entities: [Entity] = []
    
    /// Content lives here. Camera and UI do not
    private let contentParent = SKNode()
    
    /// UI
    private let restartButton = SKLabelNode()
    private let stepLabel = SKLabelNode()
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        view.contentMode = .center
        view.isMultipleTouchEnabled = true
        size = view.bounds.size
        scaleMode = .resizeFill
        backgroundColor = .darkGray
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        /// Camera
        setupCamera(in: view)
        
        /// UI
        createRestartButton()
        createStepLabel()
        
        /// Content
        addChild(contentParent)
        restartSimulation()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        guard let view = self.view else { return }
        updateUI(view: view)
    }
    
    override func willMove(from view: SKView) {
        removeContent()
        destroyWorld()
        removeAllChildren()
    }
    
    deinit {
        removeContent()
        destroyWorld()
        removeAllChildren()
    }
    
    // MARK: Camera
    
    func setupCamera(in view: UIView) {
        navCamera.gesturesView = view
        navCamera.lock = false
        navCamera.lockPan = false
        navCamera.lockScale = false
        navCamera.lockRotation = false
        navCamera.doubleTapToReset = true
        navCamera.maxScale = 50
        navCamera.minScale = 0.01
        
        self.camera = navCamera
        addChild(navCamera)
    }
    
    // MARK: UI
    
    private func createRestartButton() {
        restartButton.text = "Restart"
        restartButton.name = "button"
        restartButton.fontName = "Menlo-Bold"
        restartButton.fontSize = 20
        restartButton.fontColor = .white
        navCamera.addChild(restartButton)
    }
    
    private func createStepLabel() {
        stepLabel.fontName = "Menlo-Bold"
        stepLabel.verticalAlignmentMode = .top
        stepLabel.numberOfLines = 0
        stepLabel.fontSize = 14
        stepLabel.fontColor = .white
        stepLabel.horizontalAlignmentMode = .left
        navCamera.addChild(stepLabel)
    }
    
    private func updateUI(view: SKView) {
        restartButton.position = CGPoint(
            x: 0,
            y: view.bounds.height / 2 - view.safeAreaInsets.top - 30
        )
        
        stepLabel.position = CGPoint(
            x: -view.bounds.width / 2 + 20,
            y: view.bounds.height / 2 - view.safeAreaInsets.top - 50
        )
    }
    
    // MARK: Rollback
    
    private func restartSimulation() {
        /// Remove SpriteKit nodes and Swift references from the previous run.
        removeContent()
        
        /// Destroying the world destroys every Box2D body, shape, contact, and joint inside it.
        destroyWorld()
        
        /// Create a new physics world.
        var worldDef = b2DefaultWorldDef()
        worldDef.gravity = b2Vec2(x: 0, y: -10)
        b2WorldId = b2CreateWorld(&worldDef)
        
        /// Reset time tracking
        testFixedStepIndex = 0
        isTestPaused = false
        stepLabel.text = ""
        
        /// Recreate the content
        createGround(parent: contentParent)
        
        if shouldCreateTransientBodyBeforeBoxes {
            createTransientBody()
        }
        
        createBoxes(parent: contentParent)
        
        /// Sync rendering
        syncSpriteKitFromBox2D()
    }
    
    private func removeContent() {
        /// Remove content nodes.
        contentParent.removeAllChildren()
        
        /// Drop Swift references.
        entities.removeAll()
        transientEntity = nil
    }
    
    private func destroyWorld() {
        guard b2World_IsValid(b2WorldId) else { return }
        
        b2DestroyWorld(b2WorldId)
        b2WorldId = b2_nullWorldId
    }
    
    // MARK: Ground
    
    private func createGround(parent: SKNode) {
        let thickness: CGFloat = 15
        let groundWidth: CGFloat = 2000
        let groundCenterY: CGFloat = -300
        
        let size = CGSize(width: groundWidth, height: thickness)
        let position = CGPoint(x: 0, y: groundCenterY)
        
        /// Visual node
        let shape = SKShapeNode(rectOf: size)
        shape.fillColor = .gray
        shape.strokeColor = .black
        shape.position = position
        parent.addChild(shape)
        
        /// Box2D body
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_staticBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        
        let bodyId = b2CreateBody(b2WorldId, &bodyDef)
        
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 0
        shapeDef.filter.categoryBits = PhysicsCategory.wall
        
        /// Box2D box dimensions are half extents in meters.
        var polygon = b2MakeBox(
            meters(fromPoints: size.width / 2),
            meters(fromPoints: size.height / 2)
        )
        
        b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
        
        entities.append(Entity(
            node: shape,
            bodyId: bodyId
        ))
    }
    
    // MARK: Boxes
    
    private func createBoxes(parent: SKNode) {
        let columns: Int = 5
        let rows: Int = 5
        let cellSize: CGFloat = 60
        let nodeSize = CGSize(width: 50, height: 50)
        
        let groundCenterY: CGFloat = -300
        let groundThickness: CGFloat = 15
        let groundTopY = groundCenterY + groundThickness / 2
        let gapAboveGround: CGFloat = 1400
        
        var cells: [(row: Int, column: Int)] = []
        
        for row in 0..<rows {
            for column in 0..<columns {
                cells.append((row: row, column: column))
            }
        }
        
        /// Change body creation order without changing the grid positions.
        /// Changing order will change the simulation outcome -> Box2D determinism depends on body creation order.
        //cells.reverse()
        
        for creationIndex in cells.indices {
            let cell = cells[creationIndex]
            let row = cell.row
            let column = cell.column
            
            /// Test whether a non-colliding body inserted inside box creation changes the final hash.
            /// Result: it does not affect the boxes hash.
            if shouldCreateTransientBodyInsideBoxes && creationIndex == transientBodyBoxCreationIndex {
                createTransientBody()
            }
            
            let position = CGPoint(
                x: (CGFloat(column) - CGFloat(columns - 1) / 2) * cellSize,
                y: groundTopY + gapAboveGround + (CGFloat(row) + 0.5) * cellSize
            )
            
            createBox(
                parent: parent,
                size: nodeSize,
                position: position,
                rotation: 0.2
            )
        }
    }
    
    private func createBox(
        parent: SKNode,
        size: CGSize,
        position: CGPoint,
        rotation: CGFloat,
    ) {
        /// Visual node
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: size.width,
            height: size.height,
            cornerRadius: 3
        )
        
        let rectangle = SKSpriteNode(texture: texture)
        rectangle.colorBlendFactor = 1
        rectangle.color = .systemYellow
        
        rectangle.position = position
        rectangle.zRotation = rotation
        parent.addChild(rectangle)
        
        /// Box2D body
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_dynamicBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        bodyDef.rotation = b2MakeRot(Float(rotation))
        bodyDef.linearDamping = 0.1
        bodyDef.angularDamping = 0.1
        
        let bodyId = b2CreateBody(b2WorldId, &bodyDef)
        
        var shapeDef = b2DefaultShapeDef()
        shapeDef.filter.categoryBits = PhysicsCategory.block
        shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.block
        shapeDef.density = 1.0
        shapeDef.material.friction = 0.6
        shapeDef.material.restitution = 0.2
        
        /// Box2D box dimensions are half extents in meters.
        var polygon = b2MakeBox(
            meters(fromPoints: size.width / 2),
            meters(fromPoints: size.height / 2)
        )
        
        b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
        
        entities.append(Entity(
            node: rectangle,
            bodyId: bodyId
        ))
    }
    
    // MARK: Transient Body
    
    private func updateTransientBody() {
        guard shouldCreateTransientBodyDuringSimulation else { return }
        
        if testFixedStepIndex == transientCreateStepIndex {
            createTransientBody()
        }
        
        if testFixedStepIndex == transientDestroyStepIndex {
            destroyTransientBody()
        }
    }
    
    private func createTransientBody() {
        let size = CGSize(width: 50, height: 50)
        let position = CGPoint(x: 0, y: 300)
        
        /// Visual node
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: size.width,
            height: size.height,
            cornerRadius: 3
        )
        
        let rectangle = SKSpriteNode(texture: texture)
        rectangle.colorBlendFactor = 1
        rectangle.color = .systemCyan
        
        rectangle.position = position
        contentParent.addChild(rectangle)
        
        /// Box2D body
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_dynamicBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        
        let bodyId = b2CreateBody(b2WorldId, &bodyDef)
        
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 1.0
        shapeDef.material.restitution = 0.7
        
        /// Does not collide with boxes.
        shapeDef.filter.maskBits = PhysicsCategory.wall
        
        var polygon = b2MakeBox(
            meters(fromPoints: size.width / 2),
            meters(fromPoints: size.height / 2)
        )
        
        b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
        
        transientEntity = Entity(
            node: rectangle,
            bodyId: bodyId
        )
    }
    
    private func destroyTransientBody() {
        guard let transientEntity else { return }
        
        /// Remove node and destroy its Box2D body.
        transientEntity.node?.removeFromParent()
        
        if b2Body_IsValid(transientEntity.bodyId) {
            b2DestroyBody(transientEntity.bodyId)
        }
        
        self.transientEntity = nil
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
        
        /// Code that updates once per rendered frame
        navCamera.update()
    }
    
    override func didSimulatePhysics() {
        /// Check if enough time has passed to run fixed update
        while accumulatedTime >= fixedTimestep {
            /// Code that runs on fixed time steps
            fixedUpdate(fixedTimestep)
            accumulatedTime -= fixedTimestep
        }
    }
    
    override func didFinishUpdate() {
        /// Sync rendering
        syncSpriteKitFromBox2D()
    }
    
    // MARK: Fixed Update
    
    private func fixedUpdate(_ fixedTimestep: TimeInterval) {
        if shouldRestartSimulation {
            shouldRestartSimulation = false
            
            /// Recreate the Box2D world and content
            restartSimulation()
        }
        
        /// Stop stepping after N fixed ticks.
        /// This lets us compare the Box2D outcome after a fixed number of steps.
        guard isTestPaused == false else { return }
        
        /// Run scheduled commands at fixed-step
        updateTransientBody()
        
        /// Run the Box2D simulation
        b2World_Step(b2WorldId, Float(fixedTimestep), 4)
        testFixedStepIndex += 1
        
        stepLabel.text =
"""
steps: \(testFixedStepIndex)
previous hash: \(previousHash)
current  hash: ...
"""
        
        if testFixedStepIndex >= testFixedStepLimit {
            isTestPaused = true
            let currentHash = stateHashString()
            stepLabel.text =
"""
steps: \(testFixedStepIndex)
previous hash: \(previousHash)
current  hash: \(currentHash)
"""
            print("Paused at fixed step: \(testFixedStepIndex), hash: \(currentHash)")
            previousHash = currentHash
        }
    }
    
    private func syncSpriteKitFromBox2D() {
        for entity in entities {
            syncNodeFromBody(entity)
        }
        
        if let transientEntity {
            syncNodeFromBody(transientEntity)
        }
    }
    
    private func syncNodeFromBody(_ entity: Entity) {
        guard let node = entity.node else { return }
        guard b2Body_IsValid(entity.bodyId) else { return }
        
        let bodyPosition = b2Body_GetPosition(entity.bodyId)
        let bodyRotation = b2Body_GetRotation(entity.bodyId)
        
        node.position = CGPoint(
            x: points(fromMeters: bodyPosition.x),
            y: points(fromMeters: bodyPosition.y)
        )
        
        node.zRotation = CGFloat(b2Rot_GetAngle(bodyRotation))
    }
    
    // MARK: Hash
    
    private func stateHashString() -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        
        for entity in entities {
            guard b2Body_IsValid(entity.bodyId) else { continue }
            
            let bodyPosition = b2Body_GetPosition(entity.bodyId)
            let bodyRotation = b2Body_GetRotation(entity.bodyId)
            let bodyAngle = b2Rot_GetAngle(bodyRotation)
            
            mixHash(&hash, bodyPosition.x.bitPattern)
            mixHash(&hash, bodyPosition.y.bitPattern)
            mixHash(&hash, bodyAngle.bitPattern)
        }
        
        return String(hash, radix: 16)
    }
    
    private func mixHash(_ hash: inout UInt64, _ value: UInt32) {
        hash ^= UInt64(value)
        hash &*= 1_099_511_628_211
    }
    
    // MARK: Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        navCamera.stop()
        
        for touch in touches {
            let position = touch.location(in: self)
            let touchedNodes = nodes(at: position)
            
            if touchedNodes.contains(where: { $0.name == "button" }) {
                shouldRestartSimulation = true
                return
            }
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
