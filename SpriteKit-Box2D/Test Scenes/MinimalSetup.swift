/**
 
 # Minimal Setup
 
 Minimal test scene to run Box2D with SpriteKit.
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 25 May 2026
 
 */
import SpriteKit
import SwiftUI
import SwiftBox2D

// MARK: View

struct MinimalSetupView: View {
    var body: some View {
        ZStack {
            SpriteView(
                scene: MinimalScene(),
                preferredFramesPerSecond: 120,
                options: [.ignoresSiblingOrder],
                debugOptions: [.showsFPS, .showsNodeCount]
            )
            .ignoresSafeArea()
        }
        .background(.black)
    }
}

#Preview {
    MinimalSetupView()
}

// MARK: Scene

class MinimalScene: SKScene {
    
    // MARK: Properties
    
    /// Custom camera for inspecting the scene
    let navCamera = NavigationCamera()
    
    /// The Box2D world that owns all bodies and runs the simulation
    private let b2DWorld = B2World()
    
    /// How many SpriteKit screen points is one meter in the simulation
    static let pointsPerMeter: CGFloat = 150
    
    /// Timing
    private let fixedTimestep: TimeInterval = 1/60
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    
    /// An object that references a visual node and a Box2D body
    private struct Entity {
        weak var node: SKNode?
        let body: B2Body
        let initialPosition: CGPoint
        let initialRotation: CGFloat
    }
    
    private var entities: [Entity] = []
    
    let contentParent = SKNode()
    var shouldResetContent: Bool = false
    
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
        createButton(in: view)
        
        /// Box2D gravity
        b2DWorld.gravity = B2Vec2(x: 0, y: -10)
                
        /// Content
        self.addChild(contentParent)
        createContent(in: view)
    }
    
    override func willMove(from view: SKView) {
        removeContent()
        self.removeAllChildren()
    }
    
    deinit {
        removeContent()
        self.removeAllChildren()
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
    
    func createButton(in view: SKView) {
        let label = SKLabelNode(text: "Restart")
        label.name = "button"
        label.fontName = "Menlo-Bold"
        label.fontSize = 20
        label.fontColor = .white
        navCamera.addChild(label)
        
        label.position.y = view.bounds.height/2 - view.safeAreaInsets.top - 20
    }
    
    // MARK: Content
    
    private func createContent(in view: SKView) {
        removeContent()
        createGround(parent: contentParent, in: view)
        createBoxes(
            parent: contentParent,
            columns: 4,
            rows: 4,
            cellSize: 60,
            nodeSize: CGSize(width: 50, height: 50),
            in: view
        )
    }
    
    private func resetContent() {
        for entity in entities {
            let bodyPosition = B2Vec2(
                x: meters(fromPoints: entity.initialPosition.x),
                y: meters(fromPoints: entity.initialPosition.y)
            )
            
            let bodyRotation = B2Rot(fromRadians: Float(entity.initialRotation))
            
            /// Reset the body transform without recreating the body
            entity.body.setTransform(bodyPosition, bodyRotation)
            
            /// Remove all previous motion from the body
            entity.body.linearVelocity = B2Vec2(x: 0, y: 0)
            entity.body.angularVelocity = 0
            entity.body.setAwake(true)
            
            /// Sync SpriteKit to the reset transform
            entity.node?.position = entity.initialPosition
            entity.node?.zRotation = entity.initialRotation
        }
    }
    
    private func removeContent() {
        /// Remove all SpriteKit nodes and Box2D bodies owned by the content.
        for entity in entities {
            removeEntity(entity)
        }
        
        entities.removeAll()
    }
    
    private func removeEntity(_ entity: Entity) {
        /// Remove SpriteKit node
        entity.node?.removeFromParent()
        
        /// Remove Box2D body
        entity.body.destroy()
    }
    
    // MARK: Ground
    
    private func createGround(parent: SKNode, in view: SKView) {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let padding: CGFloat = 15
        let innerHeight = safe.height - padding * 2
        let halfY = innerHeight / 2
        let thickness: CGFloat = 15
        
        let size = CGSize(width: 2000, height: thickness)
        let position = CGPoint(x: 0, y: -halfY - thickness / 2)
        
        /// Visual node
        let shape = SKShapeNode(rectOf: size)
        shape.fillColor = .gray
        shape.strokeColor = .black
        shape.position = position
        parent.addChild(shape)
        
        /// Box2D body
        var bodyDef = b2BodyDef.default()
        bodyDef.type = B2BodyType.b2StaticBody
        /// Convert from SpriteKit points to Box2D meters with a helper function in Utilities
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 0
        
        /// Box2D box dimensions are half extents in meters
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        entities.append(Entity(
            node: shape,
            body: body,
            initialPosition: position,
            initialRotation: 0
        ))
    }
    
    // MARK: Boxes
    
    private func createBoxes(parent: SKNode, columns: Int, rows: Int, cellSize: CGFloat, nodeSize: CGSize, in view: SKView) {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let padding: CGFloat = 15
        let innerHeight = safe.height - padding * 2
        let groundTopY: CGFloat = -innerHeight / 2
        let gapAboveGround: CGFloat = 1400
        
        for row in 0..<rows {
            for column in 0..<columns {
                let x = (CGFloat(column) - CGFloat(columns - 1) / 2) * cellSize
                let y = groundTopY + gapAboveGround + (CGFloat(row) + 0.5) * cellSize
                createBox(parent: parent, size: nodeSize, position: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func createBox(parent: SKNode, size: CGSize, position: CGPoint) {
        let rectangle = SKShapeNode(rectOf: size, cornerRadius: 3)
        rectangle.fillColor = .systemYellow
        rectangle.strokeColor = .black
        rectangle.lineWidth = 1
        rectangle.position = position
        parent.addChild(rectangle)
        
        var bodyDef = b2BodyDef.default()
        bodyDef.type = B2BodyType.b2DynamicBody
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        bodyDef.linearDamping = 0.1
        bodyDef.angularDamping = 0.1
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 1.0
        shapeDef.material.friction = 0.6
        shapeDef.material.restitution = 0.2
        
        /// Box2D box dimensions are half extents in meters
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        entities.append(Entity(
            node: rectangle,
            body: body,
            initialPosition: position,
            initialRotation: 0
        ))
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
        accumulatedTime += deltaTime
        
        /// Code that updates once per rendered frame
        navCamera.update()
    }
    
    override func didSimulatePhysics() {        
        /// Reset state before physics step if asked to
        if shouldResetContent {
            resetContent()
            shouldResetContent = false
        }
        
        /// Check if enough time has passed to run fixed update
        while accumulatedTime >= fixedTimestep {
            /// Code that runs on fixed time steps
            fixedUpdate(fixedTimestep)
            accumulatedTime -= fixedTimestep
        }
    }
    
    // MARK: Fixed Update
    
    private func fixedUpdate(_ fixedTimestep: TimeInterval) {
        /// Run the Box2D simulation
        b2DWorld.step(Float(fixedTimestep), subSteps: 4)
        
        /// Copy the results of the simulation into SpriteKit
        /// This brute force strategy works, but getBodyEvents should be used for efficiency. See setup in main Scene.
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
    }
    
    // MARK: Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        navCamera.stop()
        
        for touch in touches {
            let position = touch.location(in: self)
            let touchedNodes = nodes(at: position)
            
            if touchedNodes.contains(where: { $0.name == "button" }) {
                shouldResetContent = true
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
