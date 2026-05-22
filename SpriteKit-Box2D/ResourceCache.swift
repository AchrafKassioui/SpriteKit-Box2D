/**
 
 # Resource Cache
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 22 May 2026
 
 */
import SpriteKit

// MARK: Texture Cache

enum ResourceCache {
    
    private struct TextureKey: Hashable {
        let isRectangle: Bool
        let width: CGFloat
        let height: CGFloat
        let cornerRadius: CGFloat
        let strokeThickness: CGFloat
        let strokeColor: UIColor
    }
    
    static var strokeColor: UIColor = .black
    static var strokeThickness: CGFloat = 2
    
    private static var textures: [TextureKey: SKTexture] = [:]
    
    // MARK: SKTexture
    
    static func texture(isRectangle: Bool, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> SKTexture {
        /// Rectangles use corner radius. Circles ignore it so circle cache keys stay stable.
        let cachedCornerRadius = isRectangle ? cornerRadius : 0
        
        let key = TextureKey(
            isRectangle: isRectangle,
            width: width,
            height: height,
            cornerRadius: cachedCornerRadius,
            strokeThickness: strokeThickness,
            strokeColor: strokeColor
        )
        if let cached = textures[key] { return cached }
        
        /// Generate texture with Core Graphics
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.clear(CGRect(origin: .zero, size: size))
            cg.setShouldAntialias(true)
            cg.setAllowsAntialiasing(true)
            
            let outerRect = CGRect(origin: .zero, size: size)
            
            let outerPath: UIBezierPath
            let innerPath: UIBezierPath
            
            if isRectangle {
                /// Rounded rectangle path
                outerPath = UIBezierPath(
                    roundedRect: outerRect,
                    cornerRadius: cachedCornerRadius
                )
                
                let innerRect = outerRect.insetBy(dx: strokeThickness, dy: strokeThickness)
                innerPath = UIBezierPath(
                    roundedRect: innerRect,
                    cornerRadius: max(0, cachedCornerRadius - strokeThickness)
                )
            } else {
                /// Circle path
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
