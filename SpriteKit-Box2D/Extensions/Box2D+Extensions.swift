/**
 
 # Box2D Extensions
 
 Swift wrappers and extensions on top of the Box2D C API.
 
 Achraf Kassioui
 Created 30 May 2026
 Updated 30 May 2026
 
 */
import CoreGraphics
import box2d

// MARK: C Interop
/**
 
 Swift version of `b2World_OverlapShape`.
 
 `b2World_OverlapShape` expects a C function pointer and a context pointer.
 Swift closures can't be passed directly as C function pointers when they capture variables.
 This helper wraps the C callback pattern so callers can pass a Swift closure.
 
 */
@discardableResult
func b2WorldOverlapShape(
    _ worldId: b2WorldId,
    _ proxy: inout b2ShapeProxy,
    _ filter: b2QueryFilter,
    _ callback: (b2ShapeId) -> Bool
) -> b2TreeStats {
    typealias Callback = (b2ShapeId) -> Bool
    
    return withoutActuallyEscaping(callback) { escapingCallback in
        var callbackCopy = escapingCallback
        
        return withUnsafeMutablePointer(to: &callbackCopy) { callbackPointer in
            b2World_OverlapShape(
                worldId,
                &proxy,
                filter,
                { shapeId, rawContext in
                    guard let rawContext else { return false }
                    
                    let callbackPointer = rawContext.assumingMemoryBound(
                        to: Callback.self
                    )
                    
                    return callbackPointer.pointee(shapeId)
                },
                callbackPointer
            )
        }
    }
}
