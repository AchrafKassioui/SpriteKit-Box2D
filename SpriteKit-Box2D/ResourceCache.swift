//
//  Textures.swift
//  SpriteKit-Box2D
//
//  Created by Achraf Kassioui on 19/5/2026.
//
import SpriteKit

// MARK: Cache

enum ResourceCache {
    
    private struct TextureKey: Hashable {
        let isRectangle: Bool
        let width: CGFloat
        let height: CGFloat
        let strokeThickness: CGFloat
        let strokeColor: UIColor
    }
    
    static var strokeColor: UIColor = .black
    static var strokeThickness: CGFloat = 2
    
    private static var textures: [TextureKey: SKTexture] = [:]
    
    // MARK: SKTexture
    
    static func texture(isRectangle: Bool, width: CGFloat, height: CGFloat) -> SKTexture {
        let key = TextureKey(
            isRectangle: isRectangle,
            width: width,
            height: height,
            strokeThickness: strokeThickness,
            strokeColor: strokeColor
        )
        if let cached = textures[key] { return cached }
        
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.clear(CGRect(origin: .zero, size: size))
            cg.setShouldAntialias(true)
            cg.setAllowsAntialiasing(true)
            
            let outerRect = CGRect(origin: .zero, size: size)
            let cornerRadius = isRectangle ? min(width, height) * 0.12 : 0
            
            let outerPath: UIBezierPath
            let innerPath: UIBezierPath
            
            if isRectangle {
                outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: cornerRadius)
                let innerRect = outerRect.insetBy(dx: strokeThickness, dy: strokeThickness)
                innerPath = UIBezierPath(
                    roundedRect: innerRect,
                    cornerRadius: max(0, cornerRadius - strokeThickness)
                )
            } else {
                outerPath = UIBezierPath(ovalIn: outerRect)
                innerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: strokeThickness, dy: strokeThickness))
            }
            
            /// Draw stroke as the outer filled shape
            strokeColor.setFill()
            outerPath.fill()
            
            /// Draw fill
            UIColor.white.setFill()
            innerPath.fill()
        }
        
        let texture = SKTexture(image: image)
        textures[key] = texture
        return texture
    }
    
}
