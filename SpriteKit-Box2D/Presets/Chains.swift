/**
 
 # Chains
 
 Factory functions that create chain-like assemblies using SpriteKit and Box2D.
 
 Achraf Kassioui
 Created 26 May 2026
 Updated 28 May 2026
 
 */
import SpriteKit
import SwiftBox2D

extension Scene {
    
    // MARK: Vertical Chain
    
    func createVerticalChain(linkCount: Int, startY: CGFloat, drawJoints: Bool) {
        /// Dimensions of links
        let cellSize: CGFloat = 44
        let linkSize = CGSize(width: 20, height: 48)
        /// The position of the bottom most link
        let startPosition = CGPoint(x: 0, y: startY)
        
        var chainEntities: [Entity] = []
        
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: linkSize.width,
            height: linkSize.height,
            cornerRadius: 5
        )
        
        for index in 0..<linkCount {
            let position = CGPoint(
                x: startPosition.x,
                y: startPosition.y + CGFloat(index) * cellSize
            )
            
            /// Visual node
            let node = SKSpriteNode(texture: texture)
            node.colorBlendFactor = 1
            node.color = .systemYellow
            node.position = position
            node.zPosition = ZPosition.content
            addChild(node)
            
            /// Box2D body
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2DynamicBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            bodyDef.linearDamping = 1
            bodyDef.angularDamping = 1
            
            let body = b2DWorld.createBody(bodyDef)
            
            var shapeDef = b2ShapeDef.default()
            shapeDef.density = 1
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.1
            shapeDef.filter.categoryBits = PhysicsCategory.chain
            shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.chain | PhysicsCategory.block
            
            /// Box2D box dimensions are half extents in meters.
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: linkSize.width / 2),
                halfHeight: meters(fromPoints: linkSize.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            let entity = Entity(node: node, body: body)
            chainEntities.append(entity)
            indexedEntities[body.id] = entity
        }
        
        for index in 0..<(chainEntities.count - 1) {
            let bodyA = chainEntities[index].body
            let bodyB = chainEntities[index + 1].body
            
            let bodyAPosition = bodyA.getPosition()
            let bodyBPosition = bodyB.getPosition()
            
            /// Joint pivot between two neighboring links.
            let anchorPosition = B2Vec2(
                x: (bodyAPosition.x + bodyBPosition.x) / 2,
                y: (bodyAPosition.y + bodyBPosition.y) / 2
            )
            
            /// Revolute joint connects two links at a pivot while allowing rotation.
            var jointDef = b2RevoluteJointDef.default()
            jointDef.bodyA = bodyA
            jointDef.bodyB = bodyB
            jointDef.base.collideConnected = false
            jointDef.enableLimit = true
            jointDef.lowerAngle = -.pi / 2
            jointDef.upperAngle = .pi / 2
            
            /// Box2D joint anchors are expressed in body-local coordinates.
            jointDef.base.localFrameA.p = bodyA.getLocalPoint(anchorPosition)
            jointDef.base.localFrameB.p = bodyB.getLocalPoint(anchorPosition)
            
            let joint = b2DWorld.createJoint(jointDef)
            
            /// Joint visualization
            if drawJoints {
                addJointVisualization(
                    for: joint,
                    drawsAnchorLine: true,
                    drawsAnchorPoints: true,
                    drawsBodyToAnchorLines: false,
                    drawsFrames: false
                )
            }
        }
    }
    
}

// MARK: Revolute Chain

extension Scene {
    
    func createRevoluteChain(
        links: Int,
        linksShouldCollideWithEachOther: Bool,
        drawJoints: Bool
    ) {
        let blockCount = links
        let cellSize: CGFloat = 44
        let blockSize = CGSize(width: 20, height: 38)
        
        /// Left-most link center. The chain grows toward the right.
        let startPosition = CGPoint(x: -CGFloat(blockCount - 1) * cellSize / 2, y: -150)
        let rotation: CGFloat = .pi / 2
        
        var chainEntities: [Entity] = []
        
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: blockSize.width,
            height: blockSize.height,
            cornerRadius: 6
        )
        
        for index in 0..<blockCount {
            let position = CGPoint(
                x: startPosition.x + CGFloat(index) * cellSize,
                y: startPosition.y
            )
            
            /// SpriteKit visual
            let node = SKSpriteNode(texture: texture, size: blockSize)
            node.colorBlendFactor = 1
            node.color = .systemYellow
            node.position = position
            node.zRotation = rotation
            node.zPosition = ZPosition.content
            contentParent.addChild(node)
            
            /// Box2D body
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2DynamicBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            bodyDef.rotation = B2Rot(fromRadians: Float(rotation))
            bodyDef.linearDamping = 1
            bodyDef.angularDamping = 1
            bodyDef.gravityScale = 2
            
            let body = b2DWorld.createBody(bodyDef)
            
            /// Box2D material
            var shapeDef = b2ShapeDef.default()
            shapeDef.density = 1
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.2
            shapeDef.filter.categoryBits = PhysicsCategory.chain
            shapeDef.filter.maskBits = linksShouldCollideWithEachOther
            ? PhysicsCategory.wall | PhysicsCategory.chain
            : PhysicsCategory.wall
            
            /// Rectangle collision shape
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: blockSize.width / 2),
                halfHeight: meters(fromPoints: blockSize.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            let entity = Entity(node: node, body: body)
            chainEntities.append(entity)
            indexedEntities[body.id] = entity
        }
        
        for index in 0..<(chainEntities.count - 1) {
            let bodyA = chainEntities[index].body
            let bodyB = chainEntities[index + 1].body
            
            let bodyAPosition = bodyA.getPosition()
            let bodyBPosition = bodyB.getPosition()
            
            /// Midpoint between neighboring links.
            let anchorPosition = B2Vec2(
                x: (bodyAPosition.x + bodyBPosition.x) / 2,
                y: (bodyAPosition.y + bodyBPosition.y) / 2
            )
            
            /// Revolute joint connects two links at a pivot while allowing rotation.
            var jointDef = b2RevoluteJointDef.default()
            jointDef.bodyA = bodyA
            jointDef.bodyB = bodyB
            jointDef.base.collideConnected = false
            jointDef.enableLimit = true
            jointDef.lowerAngle = -.pi / 2
            jointDef.upperAngle = .pi / 2
            
            /// Box2D joint anchors are expressed in body-local coordinates.
            jointDef.base.localFrameA.p = bodyA.getLocalPoint(anchorPosition)
            jointDef.base.localFrameB.p = bodyB.getLocalPoint(anchorPosition)
            
            let joint = b2DWorld.createJoint(jointDef)
            
            /// Joint visualization
            if drawJoints {
                addJointVisualization(
                    for: joint,
                    drawsAnchorLine: true,
                    drawsAnchorPoints: true,
                    drawsBodyToAnchorLines: false,
                    drawsFrames: false
                )
            }
        }
    }
    
}
