//
//  Chains.swift
//  SpriteKit-Box2D
//
//  Created by Achraf Kassioui on 26/5/2026.
//
import SpriteKit
import SwiftBox2D

extension Scene {
    
    // MARK: Vertical Chain
    
    func createVerticalChain(linkCount: Int, startY: CGFloat, drawJoints: Bool) {
        let cellSize: CGFloat = 44
        let linkSize = CGSize(width: 20, height: 48)
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
            entities[body.id] = entity
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
                addJointVisualization(for: joint, drawsBodyBAnchor: false)
            }
        }
    }
    
}

// MARK: Revolute Chain

extension Scene {
    
    func createRevoluteChain(parent: SKNode, linksShouldCollideWithEachOther: Bool) {
        let blockCount = 2000
        let cellSize: CGFloat = 44
        let blockSize = CGSize(width: 20, height: 38)
        /// Lowest block center Y, the chain grows upward
        let startPosition = CGPoint(x: 0, y: -150)
        let colors: [SKColor] = [.systemOrange, .systemYellow, .systemTeal, .systemRed, .white, .systemGray]
        
        var chainEntities: [Entity] = []
        
        for index in 0..<blockCount {
            let position = CGPoint(
                x: startPosition.x,
                y: startPosition.y + CGFloat(index) * cellSize
            )
            
            /// SpriteKit visual
            let texture = ResourceCache.texture(
                isRectangle: true,
                width: blockSize.width,
                height: blockSize.height,
                cornerRadius: 6
            )
            
            let node = SKSpriteNode(texture: texture, size: blockSize)
            node.colorBlendFactor = 1
            node.color = colors.randomElement() ?? .systemYellow
            node.zPosition = ZPosition.content
            parent.addChild(node)
            
            /// Box2D body
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2DynamicBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
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
            shapeDef.filter.maskBits = linksShouldCollideWithEachOther ? PhysicsCategory.wall | PhysicsCategory.chain : PhysicsCategory.wall
            
            /// Rectangle collision shape
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: blockSize.width / 2),
                halfHeight: meters(fromPoints: blockSize.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            let entity = Entity(node: node, body: body)
            chainEntities.append(entity)
            entities[body.id] = Entity(node: node, body: body)
        }
        
        for index in 0..<(chainEntities.count - 1) {
            let bodyA = chainEntities[index].body
            let bodyB = chainEntities[index + 1].body
            
            let bodyAPosition = bodyA.getPosition()
            let bodyBPosition = bodyB.getPosition()
            
            /// Midpoint
            let anchorPosition = B2Vec2(
                x: (bodyAPosition.x + bodyBPosition.x) / 2,
                y: (bodyAPosition.y + bodyBPosition.y) / 2
            )
            
            /// Revolute joint connects two blocks at a pivot while allowing rotation
            var jointDef = b2RevoluteJointDef.default()
            jointDef.bodyA = bodyA
            jointDef.bodyB = bodyB
            jointDef.base.collideConnected = false
            jointDef.enableLimit = true
            jointDef.lowerAngle = -.pi / 2
            jointDef.upperAngle = .pi / 2
            
            /// Box2D joint anchors are expressed in body-local coordinates
            jointDef.base.localFrameA.p = bodyA.getLocalPoint(anchorPosition)
            jointDef.base.localFrameB.p = bodyB.getLocalPoint(anchorPosition)
            
            _ = b2DWorld.createJoint(jointDef)
        }
    }
    
}
