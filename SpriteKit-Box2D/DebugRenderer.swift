/**
 
 # Box2D Debug Renderer
 
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
        debugDraw.DrawPolygonFcn = drawPolygonCallback
        debugDraw.DrawSolidPolygonFcn = drawSolidPolygonCallback
        debugDraw.DrawCircleFcn = drawCircleCallback
        debugDraw.DrawSolidCircleFcn = drawSolidCircleCallback
        debugDraw.DrawLineFcn = drawLineCallback
        
        debugDraw.drawShapes = true
        debugDraw.drawJoints = true
        debugDraw.drawBounds = false
        debugDraw.drawMass = false
        
        /// Large visible world bounds for debug draw.
        debugDraw.drawingBounds = B2AABB(
            lowerBound: B2Vec2(x: -10_000, y: -10_000),
            upperBound: B2Vec2(x: 10_000, y: 10_000)
        )
    }
    
    // MARK: Draw
    
    func draw(world: B2World) {
        node.removeAllChildren()
        
        /// Box2D invokes the callbacks and they add nodes into this debug layer.
        world.draw(&debugDraw)
    }
    
    private func point(from vector: B2Vec2) -> CGPoint {
        CGPoint(
            x: CGFloat(vector.x) * pointsPerMeter,
            y: CGFloat(vector.y) * pointsPerMeter
        )
    }
    
    private func color(from hexColor: B2HexColor, alpha: CGFloat = 1) -> SKColor {
        let value = Int(hexColor.rawValue)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        
        return SKColor(red: red, green: green, blue: blue, alpha: alpha)
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
    
    static func renderer(from context: UnsafeMutableRawPointer?) -> Box2DDebugRenderer? {
        guard let context else { return nil }
        return Unmanaged<Box2DDebugRenderer>
            .fromOpaque(context)
            .takeUnretainedValue()
    }
}

private func drawPolygonCallback(
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

private func drawSolidPolygonCallback(
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
    
    /// Solid polygon vertices are local, so transform them into world space.
    let vertexArray = (0..<Int(vertexCount)).map { transform.transform(vertices[$0]) }
    renderer.addPolygon(vertices: vertexArray, color: color, isSolid: true)
}

private func drawCircleCallback(
    center: B2Vec2,
    radius: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addCircle(center: center, radius: radius, color: color, isSolid: false)
}

private func drawSolidCircleCallback(
    transform: B2Transform,
    radius: Float,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addCircle(center: transform.p, radius: radius, color: color, isSolid: true)
}

private func drawLineCallback(
    pointA: B2Vec2,
    pointB: B2Vec2,
    color: B2HexColor,
    context: UnsafeMutableRawPointer?
) {
    guard let renderer = Box2DDebugRenderer.renderer(from: context) else { return }
    renderer.addLine(from: pointA, to: pointB, color: color)
}
