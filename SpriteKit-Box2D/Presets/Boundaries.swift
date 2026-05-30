//
//  Boundaries.swift
//  SpriteKit-Box2D
//
//  Created by Achraf Kassioui on 27/5/2026.
//
import SpriteKit
import SwiftBox2D

// MARK: Ground

extension Scene {
    
    func createGround(width: CGFloat) {
        let size = CGSize(width: width, height: 15)
        let position = CGPoint(x: 0, y: -300)
        
        /// Visual node
        let node = SKShapeNode(rectOf: size)
        node.fillColor = .gray
        node.strokeColor = .black
        node.position = position
        node.zPosition = ZPosition.content
        addChild(node)
        
        /// Box2D body
        var bodyDef = b2BodyDef.default()
        bodyDef.type = .b2StaticBody
        bodyDef.position = B2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        
        let body = b2DWorld.createBody(bodyDef)
        
        var shapeDef = b2ShapeDef.default()
        shapeDef.density = 0
        shapeDef.filter.categoryBits = PhysicsCategory.wall
        
        /// Box2D box dimensions are half extents in meters.
        let polygon = B2Polygon.makeBox(
            halfWidth: meters(fromPoints: size.width / 2),
            halfHeight: meters(fromPoints: size.height / 2)
        )
        
        body.createShape(polygon, shapeDef: shapeDef)
        
        indexedEntities[body.id] = Entity(node: node, body: body)
    }
    
}

// MARK: Walls

extension Scene {
    
    func createWalls(width: CGFloat) {
        let thickness: CGFloat = 15
        let baseWidth: CGFloat = width
        let sideHeight: CGFloat = 20000
        
        /// Ground center Y, relative to scene origin.
        let baseY: CGFloat = -300
        
        let baseSize = CGSize(width: baseWidth, height: thickness)
        let sideSize = CGSize(width: thickness, height: sideHeight)
        
        let basePosition = CGPoint(x: 0, y: baseY)
        
        /// Side walls grow upward from the top of the base.
        let sideY = baseY + thickness / 2 + sideHeight / 2
        
        let leftPosition = CGPoint(
            x: -baseWidth / 2 + thickness / 2,
            y: sideY
        )
        
        let rightPosition = CGPoint(
            x: baseWidth / 2 - thickness / 2,
            y: sideY
        )
        
        let sizes = [baseSize, sideSize, sideSize]
        let positions = [basePosition, leftPosition, rightPosition]
        
        for index in sizes.indices {
            let size = sizes[index]
            let position = positions[index]
            
            /// Rendering
            let node = SKShapeNode(rectOf: size)
            node.fillColor = .gray
            node.strokeColor = .black
            node.lineWidth = 2
            node.position = position
            node.zPosition = ZPosition.background
            addChild(node)
            
            /// Box2D body
            var bodyDef = b2BodyDef.default()
            bodyDef.type = .b2StaticBody
            bodyDef.position = B2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            
            let body = b2DWorld.createBody(bodyDef)
            
            var shapeDef = b2ShapeDef.default()
            shapeDef.density = 0
            shapeDef.filter.categoryBits = PhysicsCategory.wall
            
            /// Static container parts are simple rectangle collision shapes
            let polygon = B2Polygon.makeBox(
                halfWidth: meters(fromPoints: size.width / 2),
                halfHeight: meters(fromPoints: size.height / 2)
            )
            
            body.createShape(polygon, shapeDef: shapeDef)
            
            indexedEntities[body.id] = Entity(node: node, body: body)
        }
    }
    
}
