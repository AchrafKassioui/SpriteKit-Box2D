/**
 
 # Chains
 
 Factory functions that create chain-like assemblies using SpriteKit and Box2D.
 
 Achraf Kassioui
 Created 26 May 2026
 Updated 30 May 2026
 
 */
import SpriteKit
import Box2D

extension Scene {
    
    // MARK: Vertical Chain
    
    func createVerticalChain(linkCount: Int, startY: CGFloat, drawJoints: Bool) {
        /// Dimensions of links.
        let cellSize: CGFloat = 44
        let linkSize = CGSize(width: 20, height: 48)
        
        /// The position of the bottom most link.
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
            
            /// Visual node.
            let node = SKSpriteNode(texture: texture)
            node.colorBlendFactor = 1
            node.color = .systemYellow
            node.position = position
            node.zPosition = ZPosition.content
            addChild(node)
            
            /// Box2D body.
            var bodyDef = b2DefaultBodyDef()
            bodyDef.type = b2_dynamicBody
            bodyDef.position = b2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            bodyDef.linearDamping = 1
            bodyDef.angularDamping = 1
            
            let bodyID = b2CreateBody(b2WorldId, &bodyDef)
            
            /// Box2D material.
            var shapeDef = b2DefaultShapeDef()
            shapeDef.density = 1
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.1
            shapeDef.filter.categoryBits = PhysicsCategory.chain
            shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.chain | PhysicsCategory.block
            
            /// Box2D box dimensions are half extents in meters.
            var polygon = b2MakeBox(
                meters(fromPoints: linkSize.width / 2),
                meters(fromPoints: linkSize.height / 2)
            )
            
            b2CreatePolygonShape(bodyID, &shapeDef, &polygon)
            
            let entity = Entity(node: node, bodyID: bodyID)
            chainEntities.append(entity)
            indexedEntities[bodyID] = entity
        }
        
        for index in 0..<(chainEntities.count - 1) {
            let bodyIDA = chainEntities[index].bodyID
            let bodyIDB = chainEntities[index + 1].bodyID
            
            let bodyPositionA = b2Body_GetPosition(bodyIDA)
            let bodyPositionB = b2Body_GetPosition(bodyIDB)
            
            /// Joint pivot between two neighboring links.
            let anchorPosition = b2Vec2(
                x: (bodyPositionA.x + bodyPositionB.x) / 2,
                y: (bodyPositionA.y + bodyPositionB.y) / 2
            )
            
            /// Revolute joint connects two links at a pivot while allowing rotation.
            var jointDef = b2DefaultRevoluteJointDef()
            jointDef.base.bodyIdA = bodyIDA
            jointDef.base.bodyIdB = bodyIDB
            jointDef.base.collideConnected = false
            jointDef.enableLimit = true
            jointDef.lowerAngle = -.pi / 2
            jointDef.upperAngle = .pi / 2
            
            /// Box2D joint anchors are expressed in body-local coordinates.
            jointDef.base.localFrameA.p = b2Body_GetLocalPoint(bodyIDA, anchorPosition)
            jointDef.base.localFrameB.p = b2Body_GetLocalPoint(bodyIDB, anchorPosition)
            
            let jointID = b2CreateRevoluteJoint(b2WorldId, &jointDef)
            
            /// Joint visualization.
            if drawJoints {
                addJointVisualization(
                    for: jointID,
                    drawsAnchorLine: true,
                    drawsAnchorPoints: true,
                    drawsBodyToAnchorLines: false,
                    drawsFrames: false,
                    zPosition: ZPosition.viz
                )
            }
        }
    }
    
}

// MARK: Horizontal Chain

extension Scene {
    
    func createHorizontalChain(
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
            
            /// SpriteKit visual.
            let node = SKSpriteNode(texture: texture, size: blockSize)
            node.colorBlendFactor = 1
            node.color = .systemYellow
            node.position = position
            node.zRotation = rotation
            node.zPosition = ZPosition.content
            contentParent.addChild(node)
            
            /// Box2D body.
            var bodyDef = b2DefaultBodyDef()
            bodyDef.type = b2_dynamicBody
            bodyDef.position = b2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            bodyDef.rotation = b2MakeRot(Float(rotation))
            bodyDef.linearDamping = 1
            bodyDef.angularDamping = 1
            bodyDef.gravityScale = 2
            
            let bodyID = b2CreateBody(b2WorldId, &bodyDef)
            
            /// Box2D material.
            var shapeDef = b2DefaultShapeDef()
            shapeDef.density = 1
            shapeDef.material.friction = 0.5
            shapeDef.material.restitution = 0.2
            shapeDef.filter.categoryBits = PhysicsCategory.chain
            shapeDef.filter.maskBits = linksShouldCollideWithEachOther
            ? PhysicsCategory.wall | PhysicsCategory.chain
            : PhysicsCategory.wall
            
            /// Rectangle collision shape.
            var polygon = b2MakeBox(
                meters(fromPoints: blockSize.width / 2),
                meters(fromPoints: blockSize.height / 2)
            )
            
            b2CreatePolygonShape(bodyID, &shapeDef, &polygon)
            
            let entity = Entity(node: node, bodyID: bodyID)
            chainEntities.append(entity)
            indexedEntities[bodyID] = entity
        }
        
        for index in 0..<(chainEntities.count - 1) {
            let bodyIDA = chainEntities[index].bodyID
            let bodyIDB = chainEntities[index + 1].bodyID
            
            let bodyPositionA = b2Body_GetPosition(bodyIDA)
            let bodyPositionB = b2Body_GetPosition(bodyIDB)
            
            /// Midpoint between neighboring links.
            let anchorPosition = b2Vec2(
                x: (bodyPositionA.x + bodyPositionB.x) / 2,
                y: (bodyPositionA.y + bodyPositionB.y) / 2
            )
            
            /// Revolute joint connects two links at a pivot while allowing rotation.
            var jointDef = b2DefaultRevoluteJointDef()
            jointDef.base.bodyIdA = bodyIDA
            jointDef.base.bodyIdB = bodyIDB
            jointDef.base.collideConnected = false
            jointDef.enableLimit = true
            jointDef.lowerAngle = -.pi / 2
            jointDef.upperAngle = .pi / 2
            
            /// Box2D joint anchors are expressed in body-local coordinates.
            jointDef.base.localFrameA.p = b2Body_GetLocalPoint(bodyIDA, anchorPosition)
            jointDef.base.localFrameB.p = b2Body_GetLocalPoint(bodyIDB, anchorPosition)
            
            let jointID = b2CreateRevoluteJoint(b2WorldId, &jointDef)
            
            /// Joint visualization.
            if drawJoints {
                addJointVisualization(
                    for: jointID,
                    drawsAnchorLine: true,
                    drawsAnchorPoints: true,
                    drawsBodyToAnchorLines: false,
                    drawsFrames: false,
                    zPosition: ZPosition.background
                )
            }
        }
    }
    
}
