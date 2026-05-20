/**
 
 # Drag
 
 Achraf Kassioui
 Created 20 May 2026
 Updated 20 May 2026
 
 */
import SpriteKit
import SwiftUI
import SwiftBox2D

// MARK: View

struct DragView: View {
    var body: some View {
        ZStack {
            SpriteView(
                scene: DragScene(),
                preferredFramesPerSecond: 120,
                options: [.ignoresSiblingOrder],
                debugOptions: [.showsFPS, .showsNodeCount]
            )
            .ignoresSafeArea()
        }
        .background(.black)
    }
}

// MARK: Scene

class DragScene: SKScene, UIGestureRecognizerDelegate {
    
    // MARK: Properties
    
    let navCamera = NavigationCamera()
    
    static let pointsPerMeter: CGFloat = 150
    private let b2DWorld = B2World()
    
    private struct BodyNode {
        let body: B2Body
        weak var node: SKNode?
    }
    
    private var bodyNodes: [BodyNode] = []
    
    private var draggedBodyNodes: Set<B2BodyId> = []
    
    private let debugRenderer = Box2DDebugRenderer(pointsPerMeter: pointsPerMeter)
    
    // MARK: Lifecycle
    
    override func didMove(to view: SKView) {
        view.contentMode = .center
        view.isMultipleTouchEnabled = true
        size = view.bounds.size
        scaleMode = .resizeFill
        backgroundColor = .darkGray
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        /// Box2D
        b2DWorld.gravity = B2Vec2(x: 0, y: 0)
        b2DWorld.enableSleeping(false)
        
        let action = SKAction.sequence([
            .wait(forDuration: 2),
            .run { [weak self] in
                self?.b2DWorld.gravity = B2Vec2(x: 0, y: -9.8)
            }
        ])
        run(action)
        
        /// Content
        setupCamera(view: view)
        createGround(in: view)
        createBoxes(columns: 3, rows: 6, cellSize: 80, nodeSize: CGSize(width: 75, height: 75), in: view)
        
        /// Box2D debug
        addChild(debugRenderer.node)
    }
    
    // MARK: Cleanup
    
    deinit {
        for bodyNode in bodyNodes {
            removeBodyNode(bodyNode)
        }
        draggedBodyNodes.removeAll()
    }
    
    private func removeBodyNode(_ bodyNode: BodyNode) {
        bodyNode.node?.removeFromParent()
        bodyNode.body.destroy()
    }
    
    // MARK: Camera
    
    func setupCamera(view: UIView) {
        navCamera.gesturesView = view
        navCamera.gestureRecognizerDelegate = self
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
    
    // MARK: Ground
    
    private func createGround(in view: SKView) {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let padding: CGFloat = 15
        let innerHeight = safe.height - padding * 2
        let halfY = innerHeight / 2
        let thickness: CGFloat = 15
        
        let size = CGSize(width: 4000, height: thickness)
        let position = CGPoint(x: 0, y: -halfY - thickness / 2)
        
        /// Visual node
        let shape = SKShapeNode(rectOf: size)
        shape.fillColor = .gray
        shape.strokeColor = .black
        shape.position = position
        addChild(shape)
        
        /// Box2D body
        var bodyDef = b2BodyDef.default()
        bodyDef.type = B2BodyType.b2StaticBody

        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 0
        
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        bodyNodes.append(BodyNode(body: body, node: shape))
    }
    
    // MARK: Boxes
    
    private func createBoxes(columns: Int, rows: Int, cellSize: CGFloat, nodeSize: CGSize, in view: SKView) {
        let safe = view.bounds.inset(by: view.safeAreaInsets)
        let padding: CGFloat = 15
        let innerHeight = safe.height - padding * 2
        let groundTopY: CGFloat = -innerHeight / 2
        let gapAboveGround: CGFloat = 4
        
        for row in 0..<rows {
            for column in 0..<columns {
                let x = (CGFloat(column) - CGFloat(columns - 1) / 2) * cellSize
                let y = groundTopY + gapAboveGround + (CGFloat(row) + 0.5) * cellSize
                createBox(size: nodeSize, position: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func createBox(size: CGSize, position: CGPoint) {
        let rectangle = SKShapeNode(rectOf: size, cornerRadius: 12)
        rectangle.fillColor = .systemYellow
        rectangle.strokeColor = .black
        rectangle.lineWidth = 3
        rectangle.position = position
        addChild(rectangle)
        
        var bodyDef = b2BodyDef.default()
        bodyDef.type = B2BodyType.b2DynamicBody
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        bodyDef.linearDamping = 0.5
        bodyDef.angularDamping = 0.5
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 6.0
        shapeDef.material.friction = 0.6
        shapeDef.material.restitution = 0.2
        
        /// Box2D box dimensions are half extents in meters
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        bodyNodes.append(BodyNode(body: body, node: rectangle))
    }
    
    // MARK: Update
    
    override func update(_ currentTime: TimeInterval) {
        navCamera.lock = !draggedBodyNodes.isEmpty
        navCamera.update()
    }
    
    override func didEvaluateActions() {
        navCamera.didEvaluateActions()
    }
    
    override func didSimulatePhysics() {
        b2DWorld.step(1.0 / 60.0, subSteps: 4)
        
        for entity in bodyNodes {
            guard let node = entity.node else { continue }
            
            let bodyPosition = entity.body.getPosition()
            let bodyRotation = entity.body.getRotation()
            
            node.position = CGPoint(
                x: points(fromMeters: bodyPosition.x),
                y: points(fromMeters: bodyPosition.y)
            )
            node.zRotation = CGFloat(bodyRotation.angle)
        }
        
        /// Box2D debug draw
        debugRenderer.draw(world: b2DWorld)
    }
    
    // MARK: Touch
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            navCamera.stop()
            let scenePosition = touch.location(in: self)
            
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
                        
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
    }
    
    // MARK: Unit Conversion
    
    func meters(fromPoints points: CGFloat) -> Float {
        Float(points / Self.pointsPerMeter)
    }
    
    func points(fromMeters meters: Float) -> CGFloat {
        CGFloat(meters) * Self.pointsPerMeter
    }
    
}
