/**
 
 # Minimal Setup
 
 Minimal scene to run Box2D 3.x.x in C along SpriteKit in Swift.
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 30 May 2026
 
 */
import SwiftUI
import SpriteKit
import box2d

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
    
    /// Initialize a Box2D world ID.
    /// In the Box2D C API, all objects are handled with an ID.
    var b2WorldID: b2WorldId = b2_nullWorldId
    
    /// Create a data structure that links a SpriteKit node with a Box2D body id.
    struct Entity {
        weak var node: SKNode?
        let bodyID: b2BodyId
    }
    /// A dictionary that indexes entities by Box2D body id, for faster retrieval.
    var indexedEntities: [b2BodyId: Entity] = [:]
    
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
        
        /// Create a Box2D world.
        var worldDef = b2DefaultWorldDef()
        worldDef.gravity = b2Vec2(x: 0, y: 0)
        b2WorldID = b2CreateWorld(&worldDef)
        
        /// Create a Box2D body at the same position.
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_dynamicBody
        bodyDef.angularDamping = 0
        
        /// Convert position to meters.
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: sprite.position.x),
            y: meters(fromPoints: sprite.position.y)
        )
        
        let bodyID = b2CreateBody(b2WorldID, &bodyDef)
        
        /// Add a collision shape to the body.
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 1
        shapeDef.material.restitution = 0.2
        
        var box = b2MakeBox(
            meters(fromPoints: spriteSize.width / 2),
            meters(fromPoints: spriteSize.height / 2)
        )
        
        /// The & here is Swift syntax than means unsafePointer, i.e. we directly point to a location in memory.
        /// It's up to the programmer to manage the pointer's bounds and lifetime.
        b2CreatePolygonShape(bodyID, &shapeDef, &box)
        
        /// Give the body an initial spin.
        b2Body_ApplyAngularImpulse(bodyID, 0.01, true)
        
        /// Store the link between SpriteKit and Box2D.
        indexedEntities[bodyID] = Entity(node: sprite, bodyID: bodyID)
    }
    
    override func willMove(from view: SKView) {
        /// Destroy the Box2D world when the view no longer presents the scene.
        /// Destroying the world also destroys all bodies, shapes, joints, and contacts inside it.
        if b2World_IsValid(b2WorldID) {
            b2DestroyWorld(b2WorldID)
        }
        self.removeAllChildren()
    }
    
    override func update(_ currentTime: TimeInterval) {
        /// Run Box2D with a fixed timestep.
        /// This minimal setup assumes SpriteKit is rendering at 60 fps.
        b2World_Step(b2WorldID, 1/60, 4)
    }
    
    /// Before SKView renders, sync Box2D outcome with SpriteKit rendering.
    override func didFinishUpdate() {
        /// Box2D emits events for bodies that have moved.
        let bodyEvents = b2World_GetBodyEvents(b2WorldID)
        
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
            
            node.zRotation = CGFloat(b2Rot_GetAngle(moveEvent.transform.q))
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
