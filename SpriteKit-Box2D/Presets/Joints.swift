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
    
    func createVerticalChain(linkCount: Int, startY: CGFloat) {
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
            
            let _ = b2DWorld.createJoint(jointDef)
            //revoluteJoints.append(RevoluteJoint(joint: joint))
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

// MARK: Weld Joints

extension Scene {
    
    private func createWeldJoints(parent: SKNode) {
        let columns = 6
        let rows = 6
        let cellSize: CGFloat = 82
        let blockSize = CGSize(width: 75, height: 75)
        let cornerRadius: CGFloat = 9
        let colors: [SKColor] = [.systemOrange, .systemYellow, .systemTeal, .systemRed, .white, .systemGray]
        let startY: CGFloat = -150
        
        /// Start at the bottom-left of the grid, then grow right and up
        let startX = -CGFloat(columns - 1) * cellSize / 2
        
        var gridEntities: [[Entity]] = []
        
        for row in 0..<rows {
            var rowEntities: [Entity] = []
            
            for column in 0..<columns {
                let position = CGPoint(
                    x: startX + CGFloat(column) * cellSize,
                    y: startY + CGFloat(row) * cellSize
                )
                
                /// SpriteKit visual
                let texture = ResourceCache.texture(
                    isRectangle: true,
                    width: blockSize.width,
                    height: blockSize.height,
                    cornerRadius: cornerRadius
                )
                
                let node = SKSpriteNode(texture: texture, size: blockSize)
                node.colorBlendFactor = 1
                node.color = colors.randomElement() ?? .systemYellow
                node.position = position
                node.zPosition = ZPosition.content
                parent.addChild(node)
                
                /// Box2D body
                var bodyDef = b2BodyDef.default()
                bodyDef.type = .b2DynamicBody
                bodyDef.position = B2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                bodyDef.linearDamping = 4
                bodyDef.angularDamping = 4
                bodyDef.gravityScale = 4
                
                let body = b2DWorld.createBody(bodyDef)
                
                /// Box2D material
                var shapeDef = b2ShapeDef.default()
                shapeDef.density = 2
                shapeDef.material.friction = 0.5
                shapeDef.material.restitution = 0.2
                
                /// Collision shape
                let clampedCornerRadius = min(
                    cornerRadius,
                    blockSize.width / 2,
                    blockSize.height / 2
                )
                
                /// Box2D rounded boxes are a core box inflated by radius, so subtract the radius to keep the total size true to the texture
                let roundedRadius = meters(fromPoints: clampedCornerRadius)
                let innerHalfWidth = max(0.001, meters(fromPoints: blockSize.width / 2 - clampedCornerRadius))
                let innerHalfHeight = max(0.001, meters(fromPoints: blockSize.height / 2 - clampedCornerRadius))
                
                /// Rounded polygon shape
                let roundedPolygon = b2MakeRoundedBox(
                    innerHalfWidth,
                    innerHalfHeight,
                    roundedRadius
                )
                
                body.createShape(roundedPolygon, shapeDef: shapeDef)
                
                let entity = Entity(node: node, body: body)
                rowEntities.append(entity)
                entities[body.id] = Entity(node: node, body: body)
            }
            
            gridEntities.append(rowEntities)
        }
        
        for row in 0..<rows {
            for column in 0..<columns {
                let currentEntity = gridEntities[row][column]
                
                if column + 1 < columns {
                    let rightEntity = gridEntities[row][column + 1]
                    
                    /// Connect this block to the block on its right
                    var jointDef = b2WeldJointDef.default()
                    jointDef.bodyA = currentEntity.body
                    jointDef.bodyB = rightEntity.body
                    jointDef.linearHertz = 0
                    jointDef.angularHertz = 0
                    jointDef.base.collideConnected = false
                    
                    let currentPosition = currentEntity.body.getPosition()
                    let rightPosition = rightEntity.body.getPosition()
                    let anchorPosition = B2Vec2(
                        x: (currentPosition.x + rightPosition.x) / 2,
                        y: (currentPosition.y + rightPosition.y) / 2
                    )
                    
                    /// Box2D joint anchors are expressed in body-local coordinates
                    jointDef.base.localFrameA.p = currentEntity.body.getLocalPoint(anchorPosition)
                    jointDef.base.localFrameB.p = rightEntity.body.getLocalPoint(anchorPosition)
                    
                    let joint = b2DWorld.createJoint(jointDef)
                    
                    /// Joint visualization
                    let jointViz = SKShapeNode()
                    jointViz.strokeColor = .black
                    jointViz.lineWidth = 3
                    jointViz.lineCap = .round
                    jointViz.zPosition = ZPosition.background
                    parent.addChild(jointViz)
                    
                    weldJoints.append(WeldJoint(
                        joint: joint,
                        bodyA: currentEntity.body,
                        bodyB: rightEntity.body,
                        jointViz: jointViz
                    ))
                }
                
                if row + 1 < rows {
                    let topEntity = gridEntities[row + 1][column]
                    
                    /// Connect this block to the block above it
                    var jointDef = b2WeldJointDef.default()
                    jointDef.bodyA = currentEntity.body
                    jointDef.bodyB = topEntity.body
                    jointDef.linearHertz = 0
                    jointDef.angularHertz = 0
                    jointDef.base.collideConnected = false
                    
                    let currentPosition = currentEntity.body.getPosition()
                    let topPosition = topEntity.body.getPosition()
                    let anchorPosition = B2Vec2(
                        x: (currentPosition.x + topPosition.x) / 2,
                        y: (currentPosition.y + topPosition.y) / 2
                    )
                    
                    /// Box2D joint anchors are expressed in body-local coordinates
                    jointDef.base.localFrameA.p = currentEntity.body.getLocalPoint(anchorPosition)
                    jointDef.base.localFrameB.p = topEntity.body.getLocalPoint(anchorPosition)
                    
                    let joint = b2DWorld.createJoint(jointDef)
                    
                    /// Joint visualization
                    let jointViz = SKShapeNode()
                    jointViz.strokeColor = .black
                    jointViz.lineWidth = 3
                    jointViz.lineCap = .round
                    jointViz.zPosition = ZPosition.background
                    parent.addChild(jointViz)
                    
                    weldJoints.append(WeldJoint(
                        joint: joint,
                        bodyA: currentEntity.body,
                        bodyB: topEntity.body,
                        jointViz: jointViz
                    ))
                }
            }
        }
    }
    
}
