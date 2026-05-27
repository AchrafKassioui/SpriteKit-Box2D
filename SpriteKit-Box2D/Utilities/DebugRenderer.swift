/**
 
 # Box2D Debug Renderer
 
 Renders Box2D debug as SpriteKit nodes.
 
 Box2D exposes a debug draw interface via `b2DebugDraw`, a struct of C function pointers.
 This renderer assigns SpriteKit drawing functions to those slots.
 
 ## Usage
 
 Each frame after Box2D simulation in SKScene, call `draw(world:)`.
 Use `clear()` to remove the debug nodes.
 
 Note: performance drops when too many bodies are present.
 
 Achraf Kassioui
 Created 20 May 2026
 Updated 20 May 2026
 
 */
import SpriteKit
import SwiftBox2D

class Box2DDebugRenderer {
    
    let node = SKNode()
    
    private var debugDraw = b2DebugDraw.default()
    private let pointsPerMeter: CGFloat
    
    // MARK: Init
    
    init(pointsPerMeter: CGFloat) {
        self.pointsPerMeter = pointsPerMeter
        node.zPosition = 10_000
        node.name = "Box2DDebugRendererNode"
        
        debugDraw.context = Unmanaged.passUnretained(self).toOpaque()
        debugDraw.DrawPolygonFcn = drawPolygon
        debugDraw.DrawSolidPolygonFcn = drawSolidPolygon
        debugDraw.DrawCircleFcn = drawCircle
        debugDraw.DrawSolidCircleFcn = drawSolidCircle
        debugDraw.DrawSolidCapsuleFcn = drawSolidCapsule
        debugDraw.DrawLineFcn = drawLine
        debugDraw.DrawTransformFcn = drawTransformCallback
        debugDraw.DrawPointFcn = drawPointCallback
        debugDraw.DrawStringFcn = drawStringCallback
        
        /// Draw collision shapes.
        debugDraw.drawShapes = true
        /// Draw joint links.
        debugDraw.drawJoints = true
        /// Draw joint limits, motors, springs.
        debugDraw.drawJointExtras = true
        /// Draw shape AABBs.
        debugDraw.drawBounds = false
        /// Draw center of mass and mass value.
        debugDraw.drawMass = false
        /// Draw body names if set.
        debugDraw.drawBodyNames = false
        /// Draw active contact points.
        debugDraw.drawContactPoints = true
        /// Color contacts by solver graph.
        debugDraw.drawGraphColors = false
        /// Draw contact feature IDs.
        debugDraw.drawContactFeatures = false
        /// Draw contact normal directions.
        debugDraw.drawContactNormals = false
        /// Draw normal contact impulse vectors.
        debugDraw.drawContactForces = false
        /// Draw tangent friction impulse vectors.
        debugDraw.drawFrictionForces = false
        /// Draw simulation island bounds.
        debugDraw.drawIslands = false
        
        /// Scale contact force and friction vectors. 1 Newton = 1 meter
        debugDraw.forceScale = 1
        /// Scale joint debug graphics.
        debugDraw.jointScale = 1
        
        /// Large visible world bounds for debug draw.
        debugDraw.drawingBounds = B2AABB(
            lowerBound: B2Vec2(x: -5, y: -5),
            upperBound: B2Vec2(x: 5, y: 5)
        )
    }
    
    // MARK: Draw
    
    func draw(world: B2World) {
        node.removeAllChildren()
        
        /// Box2D invokes the callbacks and they add nodes into this debug layer.
        world.draw(&debugDraw)
    }
    
    func clear() {
        node.removeAllChildren()
    }
    
    // MARK: Coordinate Conversion
    
    private func point(from vector: B2Vec2) -> CGPoint {
        CGPoint(
            x: CGFloat(vector.x) * pointsPerMeter,
            y: CGFloat(vector.y) * pointsPerMeter
        )
    }
    
    // MARK: Color Conversion
    
    private func color(from hexColor: B2HexColor, alpha: CGFloat = 1) -> SKColor {
        let value = Int(hexColor.rawValue)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        
        return SKColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    // MARK: SpriteKit Drawing
    
    func addPoint(position: B2Vec2, size: Float, color: B2HexColor) {
        let radius = CGFloat(size) / 2
        
        let shape = SKShapeNode(circleOfRadius: radius)
        shape.position = point(from: position)
        shape.fillColor = self.color(from: color)
        shape.strokeColor = .clear
        
        node.addChild(shape)
    }
    
    func addTransform(_ transform: B2Transform) {
        let axisLength: Float = 0.3
        
        /// Red = local x axis.
        addLine(
            from: transform.p,
            to: transform.p + transform.q.xAxis * axisLength,
            color: .b2ColorRed
        )
        
        /// Green = local y axis.
        addLine(
            from: transform.p,
            to: transform.p + transform.q.yAxis * axisLength,
            color: .b2ColorGreen
        )
    }
    
    func addString(position: B2Vec2, text: String, color: B2HexColor) {
        let label = SKLabelNode(fontNamed: "Menlo")
        label.text = text
        label.fontSize = 10
        label.fontColor = self.color(from: color)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = point(from: position)
        
        node.addChild(label)
    }
    
    func addPolygon(vertices: [B2Vec2], color: B2HexColor, isSolid: Bool) {
        guard let firstVertex = vertices.first else { return }
        
        let path = CGMutablePath()
        path.move(to: point(from: firstVertex))
        
        for vertex in vertices.dropFirst() {
            path.addLine(to: point(from: vertex))
        }
        
        path.closeSubpath()
        
        let shape = SKShapeNode(path: path)
        shape.strokeColor = self.color(from: color)
        shape.lineWidth = 1
        
        if isSolid {
            shape.fillColor = self.color(from: color, alpha: 0.18)
        } else {
            shape.fillColor = .clear
        }
        
        node.addChild(shape)
    }
    
    func addRoundedPolygon(
        transform: B2Transform,
        localVertices: [B2Vec2],
        radius: Float,
        color: B2HexColor,
        isSolid: Bool
    ) {
        let xValues = localVertices.map { $0.x }
        let yValues = localVertices.map { $0.y }
        
        guard let minX = xValues.min(),
              let maxX = xValues.max(),
              let minY = yValues.min(),
              let maxY = yValues.max()
        else { return }
        
        let localCenter = B2Vec2(
            x: (minX + maxX) / 2,
            y: (minY + maxY) / 2
        )
        
        let worldCenter = transform.transform(localCenter)
        
        /// Box2D rounded polygons are a core polygon inflated by radius.
        let outerWidth = CGFloat(maxX - minX + radius * 2) * pointsPerMeter
        let outerHeight = CGFloat(maxY - minY + radius * 2) * pointsPerMeter
        let cornerRadius = CGFloat(radius) * pointsPerMeter
        
        let shape = SKShapeNode(
            rectOf: CGSize(width: outerWidth, height: outerHeight),
            cornerRadius: cornerRadius
        )
        
        shape.position = point(from: worldCenter)
        shape.zRotation = CGFloat(transform.q.angle)
        shape.strokeColor = self.color(from: color)
        shape.lineWidth = 1
        
        if isSolid {
            shape.fillColor = self.color(from: color, alpha: 0.18)
        } else {
            shape.fillColor = .clear
        }
        
        node.addChild(shape)
    }
    
    func addCircle(center: B2Vec2, radius: Float, color: B2HexColor, isSolid: Bool) {
        let diameter = CGFloat(radius) * pointsPerMeter * 2
        let rect = CGRect(
            x: CGFloat(center.x) * pointsPerMeter - diameter / 2,
            y: CGFloat(center.y) * pointsPerMeter - diameter / 2,
            width: diameter,
            height: diameter
        )
        
        let shape = SKShapeNode(ellipseIn: rect)
        shape.strokeColor = self.color(from: color)
        shape.lineWidth = 1
        shape.fillColor = isSolid ? self.color(from: color, alpha: 0.18) : .clear
        
        node.addChild(shape)
    }
    
    func addLine(from pointA: B2Vec2, to pointB: B2Vec2, color: B2HexColor) {
        let path = CGMutablePath()
        path.move(to: point(from: pointA))
        path.addLine(to: point(from: pointB))
        
        let shape = SKShapeNode(path: path)
        shape.strokeColor = self.color(from: color)
        shape.lineWidth = 1
        
        node.addChild(shape)
    }
    
    /// debugDraw.context has stored a pointer to the instance of Box2DDebugRenderer.
    /// This method converts the pointer back into the original Swift instance.
    static func renderer(from context: UnsafeMutableRawPointer?) -> Box2DDebugRenderer? {
        guard let context else { return nil }
        return Unmanaged<Box2DDebugRenderer>
            .fromOpaque(context)
            .takeUnretainedValue()
    }
}

// MARK: Box2D Callbacks
/**
 
 Functions called by Box2D C API.
 
 */
private func drawTransformCallback(
    transform: B2Transform,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addTransform(transform)
}

private func drawPointCallback(
    position: B2Vec2,
    size: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addPoint(position: position, size: size, color: color)
}

private func drawStringCallback(
    position: B2Vec2,
    text: UnsafePointer<CChar>?,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context),
          let text
    else { return }
    
    renderer.addString(
        position: position,
        text: String(cString: text),
        color: color
    )
}

private func drawPolygon(
    vertices: UnsafePointer<B2Vec2>?,
    vertexCount: Int32,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context),
          let vertices
    else { return }
    
    let vertexArray = (0..<Int(vertexCount)).map { vertices[$0] }
    renderer.addPolygon(vertices: vertexArray, color: color, isSolid: false)
}

private func drawSolidPolygon(
    transform: B2Transform,
    vertices: UnsafePointer<B2Vec2>?,
    vertexCount: Int32,
    radius: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context),
          let vertices
    else { return }
    
    let localVertices = (0..<Int(vertexCount)).map { vertices[$0] }
    
    if radius > 0, localVertices.count == 4 {
        renderer.addRoundedPolygon(
            transform: transform,
            localVertices: localVertices,
            radius: radius,
            color: color,
            isSolid: true
        )
    } else {
        let worldVertices = localVertices.map { transform.transform($0) }
        renderer.addPolygon(vertices: worldVertices, color: color, isSolid: true)
    }
}

private func drawCircle(
    center: B2Vec2,
    radius: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addCircle(center: center, radius: radius, color: color, isSolid: false)
}

private func drawSolidCircle(
    transform: B2Transform,
    radius: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addCircle(center: transform.p, radius: radius, color: color, isSolid: true)
}

private func drawSolidCapsule(
    pointA: B2Vec2,
    pointB: B2Vec2,
    radius: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addLine(from: pointA, to: pointB, color: color)
    renderer.addCircle(center: pointA, radius: radius, color: color, isSolid: true)
    renderer.addCircle(center: pointB, radius: radius, color: color, isSolid: true)
}

private func drawLine(
    pointA: B2Vec2,
    pointB: B2Vec2,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addLine(from: pointA, to: pointB, color: color)
}
