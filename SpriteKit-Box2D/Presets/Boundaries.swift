/**
 
 # Boundaries
 
 Factory functions for ground and walls.
 
 Achraf Kassioui
 Created 27 May 2026
 Updated 30 May 2026
 
 */
import SpriteKit
import Box2D

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
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_staticBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: position.x),
            y: meters(fromPoints: position.y)
        )
        
        let bodyId = b2CreateBody(b2WorldId, &bodyDef)
        
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 0
        shapeDef.filter.categoryBits = PhysicsCategory.wall
        
        /// Box2D box dimensions are half extents in meters.
        var polygon = b2MakeBox(
            meters(fromPoints: size.width / 2),
            meters(fromPoints: size.height / 2)
        )
        
        b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
        
        indexedEntities[bodyId] = Entity(node: node, bodyID: bodyId)
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
            var bodyDef = b2DefaultBodyDef()
            bodyDef.type = b2_staticBody
            bodyDef.position = b2Vec2(
                x: meters(fromPoints: position.x),
                y: meters(fromPoints: position.y)
            )
            
            let bodyId = b2CreateBody(b2WorldId, &bodyDef)
            
            var shapeDef = b2DefaultShapeDef()
            shapeDef.density = 0
            shapeDef.filter.categoryBits = PhysicsCategory.wall
            
            /// Static container parts are simple rectangle collision shapes.
            var polygon = b2MakeBox(
                meters(fromPoints: size.width / 2),
                meters(fromPoints: size.height / 2)
            )
            
            b2CreatePolygonShape(bodyId, &shapeDef, &polygon)
            
            indexedEntities[bodyId] = Entity(node: node, bodyID: bodyId)
        }
    }
    
}
