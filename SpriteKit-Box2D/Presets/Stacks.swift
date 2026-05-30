//
//  Grids.swift
//  SpriteKit-Box2D
//
//  Created by Achraf Kassioui on 26/5/2026.
//
import SpriteKit
import SwiftBox2D

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
    
    // MARK: Pile
    
    func createPile(baseCount: Int, startY: CGFloat) {
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
                    rotation: rotation
                )
            }
        }
    }
    
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
        var bodyDef = b2BodyDef.default()
        bodyDef.type = .b2DynamicBody
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        bodyDef.rotation = B2Rot(fromRadians: Float(rotation))
        bodyDef.linearDamping = 0.1
        bodyDef.angularDamping = 0.1
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 1
        shapeDef.material.friction = 0.6
        shapeDef.material.restitution = 0.1
        shapeDef.filter.categoryBits = PhysicsCategory.block
        shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.block | PhysicsCategory.chain
        
        /// Box2D box dimensions are half extents in meters.
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        indexedEntities[body.id] = Entity(node: node, body: body)
    }
    
}

// MARK: Weld Stack

extension Scene {
    
    func createWeldJoints(drawJoints: Bool) {
        let columns = 4
        let rows = 4
        let cellSize: CGFloat = 60
        let blockSize = CGSize(width: 50, height: 50)
        let cornerRadius: CGFloat = 9
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
                node.color = .systemYellow
                node.position = position
                node.zPosition = ZPosition.content
                contentParent.addChild(node)
                
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
                indexedEntities[body.id] = Entity(node: node, body: body)
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
                    if drawJoints {
                        addJointVisualization(
                            for: joint,
                            drawsAnchorLine: false,
                            drawsAnchorPoints: false,
                            drawsBodyToAnchorLines: true,
                            drawsFrames: false
                        )
                    }
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
                    if drawJoints {
                        addJointVisualization(
                            for: joint,
                            drawsAnchorLine: false,
                            drawsAnchorPoints: false,
                            drawsBodyToAnchorLines: true,
                            drawsFrames: false
                        )
                    }
                }
            }
        }
    }
    
}
