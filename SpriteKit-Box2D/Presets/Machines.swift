/**
 
 # Machines
 
 Achraf Kassioui
 Created 3 June 2026
 Updated 3 June 2026
 
 */
import SpriteKit
import Box2D

extension Scene {
    
    // MARK: Tumbler
    /**
     
     Circular tumbler with a spinning kinematic agitator.
     
     */
    func createTumbler(
        containerRadius: CGFloat,
        containerSegments: Int,
        agitatorSize: CGSize,
        agitatorAngularVelocity: Float,
        loadBodyCount: Int,
        loadBodySizes: [CGFloat]
    ) {
        let centerPosition = CGPoint(x: 0, y: -20)
        
        /// Build the static circular wall before the dynamic bodies so the load starts contained.
        createTumblerContainer(
            centerPosition: centerPosition,
            radius: containerRadius,
            segmentCount: containerSegments
        )
        
        /// Kinematic spinning bar.
        createTumblerArm(
            centerPosition: centerPosition,
            size: agitatorSize,
            angularVelocity: agitatorAngularVelocity
        )
        
        /// Spawn the tumbling bodies low in the tub so they settle naturally into the spinning bar.
        createTumblerLoad(
            centerPosition: centerPosition,
            containerRadius: containerRadius,
            bodyCount: loadBodyCount,
            bodySizes: loadBodySizes
        )
    }
    
    private func createTumblerContainer(
        centerPosition: CGPoint,
        radius: CGFloat,
        segmentCount: Int
    ) {
        let safeSegmentCount = max(segmentCount, 12)
        let segmentVisualThickness: CGFloat = 50
        
        /// Parent node keeps all perimeter segment sprites removable as one scene entity.
        let containerNode = SKNode()
        containerNode.position = centerPosition
        containerNode.zPosition = ZPosition.background
        contentParent.addChild(containerNode)
        
        /// Box2D static body that owns all circular wall segments.
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_staticBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: centerPosition.x),
            y: meters(fromPoints: centerPosition.y)
        )
        
        let bodyID = b2CreateBody(b2WorldId, &bodyDef)
        
        /// Wall material: high friction helps the tumbling load climb and fall instead of only sliding.
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 0
        shapeDef.material.friction = 0.85
        shapeDef.material.restitution = 0.05
        shapeDef.filter.categoryBits = PhysicsCategory.wall
        shapeDef.filter.maskBits = PhysicsCategory.block | PhysicsCategory.chain
        
        for segmentIndex in 0..<safeSegmentCount {
            let startAngle = CGFloat(segmentIndex) / CGFloat(safeSegmentCount) * .pi * 2
            let endAngle = CGFloat(segmentIndex + 1) / CGFloat(safeSegmentCount) * .pi * 2
            
            let startPoint = CGPoint(
                x: cos(startAngle) * radius,
                y: sin(startAngle) * radius
            )
            
            let endPoint = CGPoint(
                x: cos(endAngle) * radius,
                y: sin(endAngle) * radius
            )
            
            /// Segment points are local to the static body center.
            var segment = b2Segment(
                point1: b2Vec2(
                    x: meters(fromPoints: startPoint.x),
                    y: meters(fromPoints: startPoint.y)
                ),
                point2: b2Vec2(
                    x: meters(fromPoints: endPoint.x),
                    y: meters(fromPoints: endPoint.y)
                )
            )
            
            b2CreateSegmentShape(bodyID, &shapeDef, &segment)
            
            /// SpriteKit visual segment. The Box2D segment is an infinitely thin collision line.
            /// Offset the sprite outward by half its thickness so the sprite's inner edge sits on the collision segment.
            let segmentVector = CGVector(
                dx: endPoint.x - startPoint.x,
                dy: endPoint.y - startPoint.y
            )
            
            let segmentLength = hypot(segmentVector.dx, segmentVector.dy)
            let segmentMidpoint = CGPoint(
                x: (startPoint.x + endPoint.x) / 2,
                y: (startPoint.y + endPoint.y) / 2
            )
            
            let outwardLength = max(0.001, hypot(segmentMidpoint.x, segmentMidpoint.y))
            let outwardDirection = CGVector(
                dx: segmentMidpoint.x / outwardLength,
                dy: segmentMidpoint.y / outwardLength
            )
            
            let visualPosition = CGPoint(
                x: segmentMidpoint.x + outwardDirection.dx * segmentVisualThickness / 2,
                y: segmentMidpoint.y + outwardDirection.dy * segmentVisualThickness / 2
            )
            
            let texture = ResourceCache.texture(
                isRectangle: true,
                width: segmentLength,
                height: segmentVisualThickness,
                cornerRadius: 12
            )
            
            let segmentNode = SKSpriteNode(
                texture: texture,
                size: CGSize(width: segmentLength, height: segmentVisualThickness)
            )
            segmentNode.color = .gray
            segmentNode.colorBlendFactor = 1
            segmentNode.position = visualPosition
            segmentNode.zRotation = atan2(segmentVector.dy, segmentVector.dx)
            segmentNode.zPosition = ZPosition.background
            containerNode.addChild(segmentNode)
        }
        
        indexedEntities[bodyID] = Entity(node: containerNode, bodyID: bodyID)
    }
    
    private func createTumblerArm(
        centerPosition: CGPoint,
        size: CGSize,
        angularVelocity: Float
    ) {
        /// SpriteKit visual bar.
        let texture = ResourceCache.texture(
            isRectangle: true,
            width: size.width,
            height: size.height,
            cornerRadius: size.height / 2
        )
        
        let node = SKSpriteNode(texture: texture, size: size)
        node.color = .gray
        node.colorBlendFactor = 1
        node.position = centerPosition
        node.zPosition = ZPosition.content
        contentParent.addChild(node)
        
        /// Box2D kinematic body
        var bodyDef = b2DefaultBodyDef()
        bodyDef.type = b2_kinematicBody
        bodyDef.position = b2Vec2(
            x: meters(fromPoints: centerPosition.x),
            y: meters(fromPoints: centerPosition.y)
        )
        bodyDef.angularVelocity = angularVelocity
        bodyDef.enableSleep = false
        
        let bodyID = b2CreateBody(b2WorldId, &bodyDef)
        
        /// Capsule collision keeps the spinning bar from having sharp snagging corners.
        var shapeDef = b2DefaultShapeDef()
        shapeDef.density = 0
        shapeDef.material.friction = 0.95
        shapeDef.material.restitution = 0
        shapeDef.filter.categoryBits = PhysicsCategory.wall
        shapeDef.filter.maskBits = PhysicsCategory.block
        
        let capsuleRadius = meters(fromPoints: size.height / 2)
        let capsuleHalfLength = max(
            0.001,
            meters(fromPoints: (size.width - size.height) / 2)
        )
        
        var capsule = b2Capsule(
            center1: b2Vec2(x: -capsuleHalfLength, y: 0),
            center2: b2Vec2(x: capsuleHalfLength, y: 0),
            radius: capsuleRadius
        )
        
        b2CreateCapsuleShape(bodyID, &shapeDef, &capsule)
        
        indexedEntities[bodyID] = Entity(node: node, bodyID: bodyID)
    }
    
    private func createTumblerLoad(
        centerPosition: CGPoint,
        containerRadius: CGFloat,
        bodyCount: Int,
        bodySizes: [CGFloat]
    ) {
        let spacing: CGFloat = 34
        let safeBodySizes = bodySizes.isEmpty ? [22] : bodySizes
        let safeRadius = containerRadius - 42
        let columnCount = max(1, Int((safeRadius * 2) / spacing))
        let rowCount = max(1, Int(ceil(Double(bodyCount) / Double(columnCount))) + 6)
        
        let colors: [SKColor] = [
            .systemOrange,
            .systemYellow,
            .systemTeal,
            .systemRed,
            .white,
            .systemGray
        ]
        
        var createdBodyCount = 0
        
        for rowIndex in 0..<rowCount {
            for columnIndex in 0..<columnCount {
                guard createdBodyCount < bodyCount else { return }
                
                let rowOffset = rowIndex.isMultiple(of: 2) ? spacing * 0.5 : 0
                let localXPosition = -CGFloat(columnCount - 1) * spacing / 2 + CGFloat(columnIndex) * spacing + rowOffset
                let localYPosition = -safeRadius * 0.55 + CGFloat(rowIndex) * spacing
                
                /// Keep initial bodies inside the circular wall and away from the bar centerline.
                let distanceFromCenter = hypot(localXPosition, localYPosition)
                guard distanceFromCenter < safeRadius else { continue }
                guard abs(localYPosition) > 34 else { continue }
                
                let bodyIndex = createdBodyCount
                let isCircle = bodyIndex % 3 != 0
                let bodySize = safeBodySizes[bodyIndex % safeBodySizes.count]
                let position = CGPoint(
                    x: centerPosition.x + localXPosition,
                    y: centerPosition.y + localYPosition
                )
                
                /// SpriteKit visual.
                let texture = ResourceCache.texture(
                    isRectangle: !isCircle,
                    width: bodySize,
                    height: bodySize,
                    cornerRadius: isCircle ? 0 : 5
                )
                
                let node = SKSpriteNode(texture: texture, size: CGSize(width: bodySize, height: bodySize))
                node.color = colors[bodyIndex % colors.count]
                node.colorBlendFactor = 1
                node.position = position
                node.zPosition = ZPosition.content
                contentParent.addChild(node)
                
                /// Box2D dynamic body.
                var bodyDef = b2DefaultBodyDef()
                bodyDef.type = b2_dynamicBody
                bodyDef.position = b2Vec2(
                    x: meters(fromPoints: position.x),
                    y: meters(fromPoints: position.y)
                )
                bodyDef.linearDamping = 0.03
                bodyDef.angularDamping = 0.03
                
                let bodyID = b2CreateBody(b2WorldId, &bodyDef)
                
                /// Box2D material. Moderate restitution keeps the load lively without turning it into popcorn.
                var shapeDef = b2DefaultShapeDef()
                shapeDef.density = 1.2
                shapeDef.material.friction = 0.55
                shapeDef.material.restitution = 0.15
                shapeDef.filter.categoryBits = PhysicsCategory.block
                shapeDef.filter.maskBits = PhysicsCategory.wall | PhysicsCategory.block
                
                if isCircle {
                    var circle = b2Circle(
                        center: b2Vec2(x: 0, y: 0),
                        radius: meters(fromPoints: bodySize / 2)
                    )
                    
                    b2CreateCircleShape(bodyID, &shapeDef, &circle)
                } else {
                    var polygon = b2MakeBox(
                        meters(fromPoints: bodySize / 2),
                        meters(fromPoints: bodySize / 2)
                    )
                    
                    b2CreatePolygonShape(bodyID, &shapeDef, &polygon)
                }
                
                indexedEntities[bodyID] = Entity(node: node, bodyID: bodyID)
                createdBodyCount += 1
            }
        }
    }
    
}
