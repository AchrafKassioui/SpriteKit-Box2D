/**
 
 # Box2D Extensions
 
 Swift wrappers and extensions on top of the Box2D C API.
 
 Achraf Kassioui
 Created 30 May 2026
 Updated 31 May 2026
 
 */
import CoreGraphics
import Box2D

// MARK: Wrappers
/**
 
 Swift version of `b2World_OverlapShape`.
 
 `b2World_OverlapShape` expects a C function pointer and a context pointer.
 Swift closures can't be passed directly as C function pointers when they capture variables.
 This helper wraps the C callback pattern so callers can pass a Swift closure.
 
 */
@discardableResult
func b2WorldOverlapShape(
    _ worldId: b2WorldId,
    proxy: inout b2ShapeProxy,
    filter: b2QueryFilter,
    callback: (b2ShapeId) -> Bool
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

// MARK: Conformance
/**
 
 Box2D ids are C structs.
 Swift can use them as values, but not automatically as Dictionary keys or with `==`.
 
 These conformances make Box2D ids work naturally in Swift collections.
 
 */
extension b2WorldId: @retroactive Equatable {
    public static func == (lhs: b2WorldId, rhs: b2WorldId) -> Bool {
        lhs.index1 == rhs.index1 &&
        lhs.generation == rhs.generation
    }
}

extension b2WorldId: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(index1)
        hasher.combine(generation)
    }
}

extension b2BodyId: @retroactive Equatable {
    public static func == (lhs: b2BodyId, rhs: b2BodyId) -> Bool {
        lhs.index1 == rhs.index1 &&
        lhs.world0 == rhs.world0 &&
        lhs.generation == rhs.generation
    }
}

extension b2BodyId: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(index1)
        hasher.combine(world0)
        hasher.combine(generation)
    }
}

extension b2JointId: @retroactive Equatable {
    public static func == (lhs: b2JointId, rhs: b2JointId) -> Bool {
        lhs.index1 == rhs.index1 &&
        lhs.world0 == rhs.world0 &&
        lhs.generation == rhs.generation
    }
}

extension b2JointId: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(index1)
        hasher.combine(world0)
        hasher.combine(generation)
    }
}

extension b2ShapeId: @retroactive Equatable {
    public static func == (lhs: b2ShapeId, rhs: b2ShapeId) -> Bool {
        lhs.index1 == rhs.index1 &&
        lhs.world0 == rhs.world0 &&
        lhs.generation == rhs.generation
    }
}

extension b2ShapeId: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(index1)
        hasher.combine(world0)
        hasher.combine(generation)
    }
}
