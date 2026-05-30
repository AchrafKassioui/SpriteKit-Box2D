/**
 
 # Minimal Setup
 
 Minimal scene to run Box2D with SpriteKit.
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 28 May 2026
 
 */
import SpriteKit
import SwiftBox2D
import SwiftUI

// MARK: View

struct MinimalSetupView: View {
    var body: some View {
        ZStack {
            SpriteView(
                scene: MinimalScene(),
                preferredFramesPerSecond: 60,
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
    
    /// Create a Box2D physics world.
    let b2DWorld = B2World()
    
    /// Create a data structure that links SpriteKit nodes with Box2D bodies.
    struct Entity {
        weak var node: SKNode?
        let body: B2Body
    }
    /// A dictionary that indexes entities with body id, for faster retrieval.
    var indexedEntities: [B2BodyId: Entity] = [:]
    
    /// How many SpriteKit screen points is one meter in the simulation.
    /// Arbitrary value. In SpriteKit's own physics engine, 1 meter = 150 points.
    let pointsPerMeter: CGFloat = 150

    /// Setup the scene when it's presented by a view.
    override func didMove(to view: SKView) {
        size = view.bounds.size
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .darkGray
        
        /// Set the framerate to 60 fps so this minimal setup matches the fixed physics step.
        /// Note: a production app should use a fixed-step accumulator instead.
        view.preferredFramesPerSecond = 60
        
        /// Create a SpriteKit visual node.
        let spriteSize = CGSize(width: 50, height: 50)
        let sprite = SKSpriteNode(color: .systemYellow, size: spriteSize)
        sprite.position = CGPoint(x: 0, y: 0)
        addChild(sprite)
        
        /// Disable Box2D gravity.
        b2DWorld.gravity = .zero
        
        /// Create a Box2D body at the same position.
        var bodyDef = b2BodyDef.default()
        bodyDef.type = .b2DynamicBody
        bodyDef.angularDamping = 0
        
        /// Convert position to meters.
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: sprite.position.x),
            y: meters(fromPoints: sprite.position.y)
        )
        
        let body = b2DWorld.createBody(bodyDef)
        
        /// Add a collision shape to the body.
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 1
        shapeDef.material.restitution = 0.2
        
        let box = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: spriteSize.width / 2),
            halfHeight: meters(fromPoints: spriteSize.height / 2)
        )
        
        body.createShape(box, shapeDef: shapeDef)
        
        /// Give the body an initial spin.
        body.applyAngularImpulse(0.01, true)
        
        /// Store the link between SpriteKit and Box2D.
        indexedEntities[body.id] = Entity(node: sprite, body: body)
    }
    
    override func update(_ currentTime: TimeInterval) {
        /// Run Box2D with a fixed timestep.
        /// This minimal setup assumes SpriteKit is rendering at 60 fps.
        b2DWorld.step(1.0 / 60.0, subSteps: 4)
    }
    
    /// Before SKView renders, sync Box2D outcome with SpriteKit rendering.
    override func didFinishUpdate() {
        /// Box2D emits events for bodies that have moved.
        let bodyEvents = b2DWorld.getBodyEvents()
        
        /// If no body moved, do nothing.
        guard let moveEvents = bodyEvents.moveEvents else { return }
        
        /**
         
         bodyEvents has two separate pieces:
         
         - moveEvents: a memory address to the first event in a C array
         - moveCount: how many move events are stored there
         
         The events are stored next to each other in memory.
         Swift does not see this as a normal Array, so we convert moveCount to an integer and use it as loop counter.
         
         */
        for index in 0..<Int(bodyEvents.moveCount) {
            let moveEvent = moveEvents[index]
            
            guard let entity = indexedEntities[moveEvent.bodyId] else { continue }
            guard let node = entity.node else { continue }
            
            /// Apply Box2D new transforms after unit conversion
            node.position = CGPoint(
                x: points(fromMeters: moveEvent.transform.p.x),
                y: points(fromMeters: moveEvent.transform.p.y)
            )
            
            node.zRotation = CGFloat(moveEvent.transform.q.angle)
        }
    }
    
    // MARK: Unit Conversion
    
    func meters(fromPoints points: CGFloat) -> Float {
        Float(points / pointsPerMeter)
    }
    
    func points(fromMeters meters: Float) -> CGFloat {
        CGFloat(meters) * pointsPerMeter
    }
    
}
