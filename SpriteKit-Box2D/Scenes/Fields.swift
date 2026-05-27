/**
 
 # SKFieldNode + Box2D
 
 A scene that mixes SpriteKit physics with Box2D.
 - Blocks are subject to a noise physics field (SpriteKit)
 - Blocks collide with each other (Box2D)
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 26 May 2026
 
 */
import SwiftUI
import SpriteKit
import SwiftBox2D

// MARK: View

struct FieldsView: View {
    var body: some View {
        ZStack {
            SpriteView(
                scene: FieldsScene(),
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
    FieldsView()
}

// MARK: Scene

class FieldsScene: SKScene, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    let navCamera = NavigationCamera()
    let contentParent = SKNode()
    
    private struct Entity {
        weak var node: SKNode?
        let body: B2Body
    }
    private var entities: [Entity] = []
    
    private let palette: [SKColor] = [.systemOrange, .systemYellow, .systemTeal, .systemRed, .white, .systemGray]
    
    /// SpriteKit physics
    private enum PhysicsCategory {
        static let block: UInt32 = 1 << 0
        static let wall: UInt32 = 1 << 1
        static let field: UInt32 = 1 << 2
    }
    
    /// When true, SpriteKit physics/fields feed motion into Box2D before Box2D solves.
    private let shouldMergeSpriteKitPhysics = true
    
    /// Box2D
    private let b2DWorld = B2World()
    static let pointsPerMeter: CGFloat = 150
    private var pendingBox2DCommands: [() -> Void] = []
    
    /// Tap state
    private var tapStartLocation: CGPoint?
    private var tapStartTime: TimeInterval?
    
    /// Perf
    var PhysicsProfiler = PhysicsStepProfiler(label: "Box2D physics")
    var beforePhysicsTime: TimeInterval = CACurrentMediaTime()
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        view.contentMode = .center
        size = view.bounds.size
        backgroundColor = .darkGray
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        physicsWorld.gravity = .zero
        
        b2DWorld.gravity = B2Vec2(x: 0, y: 0)
        
        addChild(contentParent)
        
        setupCamera(view: view)
        createWalls(parent: contentParent)
        createBlocks(parent: contentParent)
        createField(parent: contentParent)
        //scheduleGravityDrop(afterSeconds: 2)
    }
    
    override func willMove(from view: SKView) {
        self.removeAllChildren()
    }
    
    // MARK: Camera
    
    func setupCamera(view: UIView) {
        navCamera.gestureRecognizerDelegate = self
        navCamera.gesturesView = view
        navCamera.lock = false
        navCamera.lockPan = false
        navCamera.lockScale = false
        navCamera.lockRotation = false
        navCamera.doubleTapToReset = false
        navCamera.maxScale = 50
        navCamera.minScale = 0.01
        navCamera.area = CGSize(width: 15000, height: 30000)
        
        self.camera = navCamera
        addChild(navCamera)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: Gravity
    
    private func scheduleGravityDrop(afterSeconds seconds: TimeInterval) {
        run(.sequence([
            .wait(forDuration: seconds),
            .run { [weak self] in
                guard let self else { return }
                self.b2DWorld.gravity = B2Vec2(x: 0, y: -10)
                for entity in entities {
                    entity.body.setAwake(true)
                }
            }
        ]))
    }
    
    // MARK: Explode
    
    private func explode(at scenePoint: CGPoint) {
        let explosionPoint = scenePoint
        
        /// Run Box2D mutations during the Box2D phase so SpriteKit sync cannot overwrite them.
        pendingBox2DCommands.append { [weak self] in
            guard let self else { return }
            
            var explosion = b2ExplosionDef.default()
            
            /// Center of explosion in Box2D world meters.
            explosion.position = B2Vec2(
                x: meters(fromPoints: explosionPoint.x),
                y: meters(fromPoints: explosionPoint.y)
            )
            
            /// Full strength inside this radius.
            explosion.radius = 1
            
            /// Strength fades to zero across this extra distance.
            explosion.falloff = 1.0
            
            /// Positive pushes away, negative pulls inward.
            explosion.impulsePerLength = 50.0
            
            self.b2DWorld.explode(explosion)
        }
    }
    
    // MARK: Field
    
    private func createField(parent: SKNode) {
        let field = SKFieldNode.noiseField(withSmoothness: 1, animationSpeed: 1)
        field.categoryBitMask = PhysicsCategory.field
        field.strength = 10
        field.falloff = 0
        parent.addChild(field)
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
            
            /// SpriteKit body for fields
            wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: width, height: height))
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.affectedByGravity = false
            wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            wall.physicsBody?.collisionBitMask = PhysicsCategory.block
            wall.physicsBody?.contactTestBitMask = 0
            wall.physicsBody?.fieldBitMask = 0
            
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
        
        /// Top
        makeWall(
            width: containerWidth,
            height: wallThickness,
            position: CGPoint(x: 0, y: floorY + wallHeight)
        )
    }
    
    // MARK: Blocks

    private func createBlocks(parent: SKNode) {
        let columns = 60
        let rows = 60
        let cellSize: CGFloat = 100
        let blockSizes: [CGFloat] = [15, 30, 60, 75, 100]
        let cornerRadius: CGFloat = 9
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
                
                let body = createBody(
                    isRectangle: isRectangle,
                    width: width,
                    height: height,
                    position: position
                )
                
                entities.append(Entity(node: block, body: body))
                index += 1
            }
        }
        
        print("\nBox2D Physics")
        print("\(entities.count) bodies")
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
            cornerRadius: cornerRadius,
        )
        
        let block = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
        block.color = color
        block.colorBlendFactor = 1
        
        /// SpriteKit body for fields
        if isRectangle {
            block.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: width, height: height))
        } else {
            block.physicsBody = SKPhysicsBody(circleOfRadius: width / 2)
        }
        
        block.physicsBody?.isDynamic = shouldMergeSpriteKitPhysics
        block.physicsBody?.affectedByGravity = false
        block.physicsBody?.density = 2
        block.physicsBody?.friction = 0.5
        block.physicsBody?.restitution = 0.2
        block.physicsBody?.linearDamping = 0.1
        block.physicsBody?.angularDamping = 0.1
        
        /// SpriteKit only collides blocks with walls.
        block.physicsBody?.categoryBitMask = PhysicsCategory.block
        block.physicsBody?.collisionBitMask = PhysicsCategory.wall
        block.physicsBody?.contactTestBitMask = 0
        block.physicsBody?.fieldBitMask = PhysicsCategory.field
        
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
        bodyDef.linearDamping = 0.1
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
            /// Circle block.
            let circle = B2Circle(
                center: B2Vec2(x: 0, y: 0),
                radius: meters(fromPoints: width / 2)
            )
            body.createShape(circle, shapeDef: shapeDef)
        }
        
        return body
    }
    
    // MARK: Update
    
    override func update(_ currentTime: TimeInterval) {
        navCamera.update()
    }
    
    override func didEvaluateActions() {
        /// Time before physics
        beforePhysicsTime = CACurrentMediaTime()
    }
    
    override func didSimulatePhysics() {
        if shouldMergeSpriteKitPhysics {
            /// Feed SpriteKit field and wall response into Box2D.
            for entity in entities {
                guard let node = entity.node else { continue }
                
                let spriteKitVelocity = node.physicsBody?.velocity ?? .zero
                let spriteKitAngularVelocity = node.physicsBody?.angularVelocity ?? 0
                
                let box2DPosition = B2Vec2(
                    x: meters(fromPoints: node.position.x),
                    y: meters(fromPoints: node.position.y)
                )
                
                let box2DVelocity = B2Vec2(
                    x: meters(fromPoints: spriteKitVelocity.dx),
                    y: meters(fromPoints: spriteKitVelocity.dy)
                )
                
                guard
                    box2DPosition.x.isFinite,
                    box2DPosition.y.isFinite,
                    box2DVelocity.x.isFinite,
                    box2DVelocity.y.isFinite
                else { continue }
                
                entity.body.setTransform(
                    box2DPosition,
                    .init(fromRadians: Float(node.zRotation))
                )
                
                /// Preserve SpriteKit field momentum before Box2D solves contacts.
                entity.body.linearVelocity = box2DVelocity
                entity.body.angularVelocity = Float(spriteKitAngularVelocity)
            }
        }
        
        /// Apply queued Box2D-only operations after sync and before stepping.
        let box2DCommands = pendingBox2DCommands
        pendingBox2DCommands.removeAll()
        
        for command in box2DCommands {
            command()
        }
        
        /// Step Box2D after SpriteKit physics.
        b2DWorld.step(1.0 / 60.0, subSteps: 4)
        
        let afterPhysicsTime = CACurrentMediaTime()
        let physicsStepMS = (afterPhysicsTime - beforePhysicsTime) * 1000
        PhysicsProfiler.record(milliseconds: physicsStepMS)
        
        /// Copy Box2D's result back into SpriteKit.
        for entity in entities {
            guard let node = entity.node else { continue }
            
            let bodyPosition = entity.body.getPosition()
            let bodyRotation = entity.body.getRotation()
            let bodyVelocity = entity.body.linearVelocity
            let bodyAngularVelocity = entity.body.angularVelocity
            
            node.position = CGPoint(
                x: points(fromMeters: bodyPosition.x),
                y: points(fromMeters: bodyPosition.y)
            )
            node.zRotation = CGFloat(bodyRotation.angle)
            
            /// Keep SpriteKit's proxy body synchronized only when it participates in the merge.
            if shouldMergeSpriteKitPhysics {
                node.physicsBody?.velocity = CGVector(
                    dx: points(fromMeters: bodyVelocity.x),
                    dy: points(fromMeters: bodyVelocity.y)
                )
                node.physicsBody?.angularVelocity = CGFloat(bodyAngularVelocity)
            }
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


