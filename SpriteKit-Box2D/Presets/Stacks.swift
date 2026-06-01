/**
 
 # Stack
 
 Factory functions for stacks of blocks.
 
 Achraf Kassioui
 Created 26 May 2026
 Updated 31 May 2026
 
 */
import SpriteKit
import Box2D

extension Scene {
    
    // MARK: Stack
    
    func createStack(
        columns: Int,
        rows: Int,
        startY: CGFloat,
    ) {
        let cellSize: CGFloat = 60
        let blockSize = CGSize(width: 50, height: 50)
        let startX = -CGFloat(columns - 1) * cellSize / 2
        
        for row in 0..<rows {
            for column in 0..<columns {
                let position = CGPoint(
                    x: startX + CGFloat(column) * cellSize,
                    y: startY + CGFloat(row) * cellSize
                )
                
                createBlock(
                    size: blockSize,
                    position: position,
                    rotation: 0
                )
            }
        }
    }
    
    // MARK: Pyramid
    
    func createPyramid(baseCount: Int, startY: CGFloat) {
        let cellSize: CGFloat = 52
        let blockSize = CGSize(width: 50, height: 50)
        
        for row in 0..<baseCount {
            let blocksInRow = baseCount - row
            let rowWidth = CGFloat(blocksInRow - 1) * cellSize
            let rowStartX = -rowWidth / 2
            
            for column in 0..<blocksInRow {
                let blockIndex = row * baseCount + column
                
                /// Higher rows lean more, so the top of the pile is already biased toward collapse.
                let rowLean = CGFloat(row) * 5
                
                /// Alternate small offsets so contacts are not perfectly centered.
                let horizontalOffset = CGFloat((blockIndex % 3) - 1) * 1.6
                
                let position = CGPoint(
                    x: rowStartX + CGFloat(column) * cellSize + rowLean + horizontalOffset,
                    y: startY + CGFloat(row) * cellSize
                )
                
                /// Higher blocks are rotated more, making them roll / slide once the pile hits the ground.
                let rotationDirection: CGFloat = row.isMultiple(of: 2) ? 1 : -1
                let rotationAmount = CGFloat(row + 1) * 0.065
                let rotation = rotationDirection * rotationAmount
                
                createBlock(
                    size: blockSize,
                    position: position,
                    rotation: 0
                )
            }
        }
    }
    
    // MARK: Create Block
    
    private func createBlock(
        size: CGSize,
        position: CGPoint,
        rotation: CGFloat
    ) {
        /// Visual node
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: size.width,
            height: size.height,
            cornerRadius: 5
        )
        
        let node = SKSpriteNode(texture: texture)
        node.colorBlendFactor = 1
        node.color = .systemYellow
        node.position = position
        node.zRotation = rotation
        node.zPosition = ZPosition.content
        addChild(node)
        
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
        
        let bodyID = b2CreateBody(b2WorldId, &bodyDef)
        
        /// Box2D material
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 1
        shapeDef.material.friction = 0.6
        shapeDef.material.restitution = 0.1
        shapeDef.filter.categoryBits = PhysicsCategory.block
        shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.block | PhysicsCategory.chain
        
        /// Box2D box dimensions are half extents in meters.
        var polygon = b2MakeBox(
            meters(fromPoints: size.width / 2),
            meters(fromPoints: size.height / 2)
        )
        
        b2CreatePolygonShape(bodyID, &shapeDef, &polygon)
        
        indexedEntities[bodyID] = Entity(node: node, bodyID: bodyID)
    }
    
}

// MARK: Large Pile

extension Scene {
    
    func createBigPile(
        columns: Int,
        rows: Int,
        startY: CGFloat
    ) {
        let cellSize: CGFloat = 100
        let blockSizes: [CGFloat] = [15, 30, 60, 75, 100]
        let cornerRadius: CGFloat = 9
        
        let colors: [SKColor] = [
            .systemOrange,
            .systemYellow,
            .systemTeal,
            .systemRed,
            .white,
            .systemGray
        ]
        
        let gridWidth = CGFloat(columns) * cellSize
        let originX = -gridWidth / 2 + cellSize / 2
        let originY = startY + cellSize / 2
        
        for row in 0..<rows {
            for column in 0..<columns {
                let blockIndex = row * columns + column
                
                /// Deterministic shape variation: same pile every time this preset is loaded.
                let isRectangle = blockIndex.isMultiple(of: 2)
                
                /// Deterministic size variation, replacing randomElement().
                let width = blockSizes[blockIndex % blockSizes.count]
                let heightIndex = (blockIndex / blockSizes.count + column + row) % blockSizes.count
                let height = isRectangle ? blockSizes[heightIndex] : width
                
                /// Deterministic color variation.
                let color = colors[blockIndex % colors.count]
                
                /// Deterministic small offsets, replacing CGFloat.random().
                /// This keeps the pile imperfect without making the preset random.
                let horizontalOffsetPattern = CGFloat((blockIndex % 5) - 2)
                let verticalOffsetPattern = CGFloat(((blockIndex / 5) % 5) - 2)
                let xOffset = horizontalOffsetPattern * cellSize * 0.025
                let yOffset = verticalOffsetPattern * cellSize * 0.025
                
                let position = CGPoint(
                    x: originX + CGFloat(column) * cellSize + xOffset,
                    y: originY + CGFloat(row) * cellSize + yOffset
                )
                
                /// SpriteKit visual node.
                let texture = ResourceCache.texture(
                    isRectangle: isRectangle,
                    width: width,
                    height: height,
                    cornerRadius: cornerRadius
                )
                
                let node = SKSpriteNode(texture: texture, size: CGSize(width: width, height: height))
                node.color = color
                node.colorBlendFactor = 1
                node.position = position
                node.zPosition = ZPosition.content
                contentParent.addChild(node)
                
                /// Box2D body.
                var bodyDef = b2DefaultBodyDef()
                bodyDef.type = b2_dynamicBody
                bodyDef.position = b2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                bodyDef.linearDamping = 0
                bodyDef.angularDamping = 0.1
                
                let bodyID = b2CreateBody(b2WorldId, &bodyDef)
                
                /// Box2D material.
                var shapeDef = b2DefaultShapeDef()
                shapeDef.density = 2
                shapeDef.material.friction = 0.5
                shapeDef.material.restitution = 0.2
                shapeDef.filter.categoryBits = PhysicsCategory.block
                shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.block | PhysicsCategory.chain
                
                if isRectangle {
                    /// Box2D box dimensions are half extents in meters.
                    var polygon = b2MakeBox(
                        meters(fromPoints: width / 2),
                        meters(fromPoints: height / 2)
                    )
                    
                    b2CreatePolygonShape(bodyID, &shapeDef, &polygon)
                } else {
                    /// Circle block matches the visual circle radius.
                    var circle = b2Circle(
                        center: b2Vec2(x: 0, y: 0),
                        radius: meters(fromPoints: width / 2)
                    )
                    
                    b2CreateCircleShape(bodyID, &shapeDef, &circle)
                }
                
                indexedEntities[bodyID] = Entity(node: node, bodyID: bodyID)
            }
        }
        
        print("\nLarge pile of \(columns * rows) bodies")
    }
    
}

// MARK: Weld Stack

extension Scene {
    
    func createWeldJoints(columns: Int, rows: Int, drawJoints: Bool) {
        let cellSize: CGFloat = 60
        let blockSize = CGSize(width: 50, height: 50)
        let cornerRadius: CGFloat = 9
        let startY: CGFloat = -150
        
        /// Start at the bottom-left of the grid, then grow right and up.
        let startX = -CGFloat(columns - 1) * cellSize / 2
        
        var gridEntities: [[Entity]] = []
        
        for row in 0..<rows {
            var rowEntities: [Entity] = []
            
            for column in 0..<columns {
                let position = CGPoint(
                    x: startX + CGFloat(column) * cellSize,
                    y: startY + CGFloat(row) * cellSize
                )
                
                /// SpriteKit visual.
                let texture = ResourceCache.texture(
                    isRectangle: true,
                    width: blockSize.width,
                    height: blockSize.height,
                    cornerRadius: cornerRadius
                )
                
                let node = SKSpriteNode(texture: texture, size: blockSize)
                node.colorBlendFactor = 1
                node.color = .systemYellow
                node.position = position
                node.zPosition = ZPosition.content
                contentParent.addChild(node)
                
                /// Box2D body.
                var bodyDef = b2DefaultBodyDef()
                bodyDef.type = b2_dynamicBody
                bodyDef.position = b2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                bodyDef.linearDamping = 1
                bodyDef.angularDamping = 1
                bodyDef.gravityScale = 2
                
                let bodyID = b2CreateBody(b2WorldId, &bodyDef)
                
                /// Box2D material.
                var shapeDef = b2DefaultShapeDef()
                shapeDef.density = 2
                shapeDef.material.friction = 0.5
                shapeDef.material.restitution = 0.2
                shapeDef.filter.categoryBits = PhysicsCategory.block
                shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.block | PhysicsCategory.chain
                
                /// Collision shape.
                let clampedCornerRadius = min(
                    cornerRadius,
                    blockSize.width / 2,
                    blockSize.height / 2
                )
                
                /// Box2D rounded boxes are a core box inflated by radius, so subtract the radius to keep the total size true to the texture.
                let roundedRadius = meters(fromPoints: clampedCornerRadius)
                let innerHalfWidth = max(0.001, meters(fromPoints: blockSize.width / 2 - clampedCornerRadius))
                let innerHalfHeight = max(0.001, meters(fromPoints: blockSize.height / 2 - clampedCornerRadius))
                
                /// Rounded polygon shape.
                var roundedPolygon = b2MakeRoundedBox(
                    innerHalfWidth,
                    innerHalfHeight,
                    roundedRadius
                )
                
                b2CreatePolygonShape(bodyID, &shapeDef, &roundedPolygon)
                
                let entity = Entity(node: node, bodyID: bodyID)
                rowEntities.append(entity)
                indexedEntities[bodyID] = entity
            }
            
            gridEntities.append(rowEntities)
        }
        
        for row in 0..<rows {
            for column in 0..<columns {
                let currentEntity = gridEntities[row][column]
                
                if column + 1 < columns {
                    let rightEntity = gridEntities[row][column + 1]
                    
                    /// Connect this block to the block on its right.
                    var jointDef = b2DefaultWeldJointDef()
                    jointDef.base.bodyIdA = currentEntity.bodyID
                    jointDef.base.bodyIdB = rightEntity.bodyID
                    jointDef.linearHertz = 0
                    jointDef.angularHertz = 0
                    jointDef.base.collideConnected = false
                    
                    let currentPosition = b2Body_GetPosition(currentEntity.bodyID)
                    let rightPosition = b2Body_GetPosition(rightEntity.bodyID)
                    
                    let anchorPosition = b2Vec2(
                        x: (currentPosition.x + rightPosition.x) / 2,
                        y: (currentPosition.y + rightPosition.y) / 2
                    )
                    
                    /// Box2D joint anchors are expressed in body-local coordinates.
                    jointDef.base.localFrameA.p = b2Body_GetLocalPoint(currentEntity.bodyID, anchorPosition)
                    jointDef.base.localFrameB.p = b2Body_GetLocalPoint(rightEntity.bodyID, anchorPosition)
                    
                    let jointID = b2CreateWeldJoint(b2WorldId, &jointDef)
                    
                    /// Joint visualization.
                    if drawJoints {
                        addJointVisualization(
                            for: jointID,
                            drawsAnchorLine: false,
                            drawsAnchorPoints: false,
                            drawsBodyToAnchorLines: true,
                            drawsFrames: false,
                            zPosition: ZPosition.background
                        )
                    }
                }
                
                if row + 1 < rows {
                    let topEntity = gridEntities[row + 1][column]
                    
                    /// Connect this block to the block above it.
                    var jointDef = b2DefaultWeldJointDef()
                    jointDef.base.bodyIdA = currentEntity.bodyID
                    jointDef.base.bodyIdB = topEntity.bodyID
                    jointDef.linearHertz = 0
                    jointDef.angularHertz = 0
                    jointDef.base.collideConnected = false
                    
                    let currentPosition = b2Body_GetPosition(currentEntity.bodyID)
                    let topPosition = b2Body_GetPosition(topEntity.bodyID)
                    
                    let anchorPosition = b2Vec2(
                        x: (currentPosition.x + topPosition.x) / 2,
                        y: (currentPosition.y + topPosition.y) / 2
                    )
                    
                    /// Box2D joint anchors are expressed in body-local coordinates.
                    jointDef.base.localFrameA.p = b2Body_GetLocalPoint(currentEntity.bodyID, anchorPosition)
                    jointDef.base.localFrameB.p = b2Body_GetLocalPoint(topEntity.bodyID, anchorPosition)
                    
                    let jointID = b2CreateWeldJoint(b2WorldId, &jointDef)
                    
                    /// Joint visualization.
                    if drawJoints {
                        addJointVisualization(
                            for: jointID,
                            drawsAnchorLine: false,
                            drawsAnchorPoints: false,
                            drawsBodyToAnchorLines: true,
                            drawsFrames: false,
                            zPosition: ZPosition.background
                        )
                    }
                }
            }
        }
    }
    
}
