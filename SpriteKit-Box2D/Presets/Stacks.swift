//
//  Grids.swift
//  SpriteKit-Box2D
//
//  Created by Achraf Kassioui on 26/5/2026.
//
import SpriteKit
import SwiftBox2D

// MARK: Stacks

extension Scene {
    
    func createBlockGrid(
        columns: Int,
        rows: Int,
        startY: CGFloat,
        randomRotation: Bool
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
                
                let rotation: CGFloat = randomRotation
                ? CGFloat.random(in: -0.25...0.25)
                : 0
                
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
        
        entities[body.id] = Entity(node: node, body: body)
    }
    
}
