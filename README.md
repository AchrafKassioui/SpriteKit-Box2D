# SpriteKit Box2D

This project shows how to integrate Box2D 3.x.x with SpriteKit.

## Run The App

- You need a Mac with Xcode, and optionally an iOS device.
- Download this project and open it in Xcode.
- Update signing to use your own Apple Developer account.
- Select a target device or simulator.
- For best performance, run the app with the scheme set to Release instead of Debug.
- Build and run.
- Enjoy the amazing Box2D version 3 with SpriteKit.

## Swift & C

Box2D version 3 is written in C. This projects shows how to use C and Swift in the same Xcode project.

### Pick the C Library

Download Box2D [from the official repository](https://github.com/erincatto/box2d). I cloned the latest commit, `f2086ed` as of May 2026. You can download the latest release instead ([3.1.1](https://github.com/erincatto/box2d/releases/tag/v3.1.1), June 2025). It's up to you to choose which version you wish to work with.

### Copy the Source Code

Create the following folder hierarchy in the Xcode project. By convention, Vendor is used to gather third-party libraries:

```
SpriteKit-Box2D/  ← app target’s source folder
  Vendor/
    Box2D/
      include/    ← copy files from box2d repo
      src/        ← copy files from box2d repo
      LICENSE
```

<img src="SpriteKit-Box2D/Media/Folder Hierarchy.png" alt="Folder Hierarchy" style="width:50%;" />

Locate the "include" and "src" folders inside the Box2D source code, and copy their content to their respective folders in the Xcode project.

### Create a Module Map

This is the first magic step: create a file called "module.modulemap", and put it inside the "include" folder. Xcode knows how to create .modulemap files: go to File > New > File from Template. You'll find a template for this kind of file:

<img src="SpriteKit-Box2D/Media/Module Map Template.png" alt="Module Map Template" style="width:100%;" />

Add the following code inside that file:

```C
module box2d {
    header "box2d/box2d.h"
    export *
}
```

This code is read by Clang, the compiler that handles C, Objective-C, and C++. Swift, C, Objective-C, and C++ are all first class languages on Apple platforms and they can work together in the same Xcode project.

The modulemap file is what will allow you to write `import box2d` inside your Swift files. In fact, you can change the name of the module right there. For example, you can change to `module Box2D` which is more Swift looking:

```C
module Box2D {
    header "box2d/box2d.h"
    export *
}
```

### Update Build Settings

Next, we need to tell Xcode and the compiler about these new additions. Go to Project Settings > Targets > YourApp > Build Settings.

<img src="SpriteKit-Box2D/Media/Build Settings.png" alt="Build Settings" style="width:100%;" />

Search for "Module Map File" and add the path to it:

```
$(SRCROOT)/SpriteKit-Box2D/Vendor/Box2D/include/module.modulemap
```

<img src="SpriteKit-Box2D/Media/Module Map File.png" alt="Module Map File" style="width:100%;" />

Then search for "Header Search Paths" and add the paths of the library's source code:

```
$(SRCROOT)/SpriteKit-Box2D/Vendor/Box2D/include
$(SRCROOT)/SpriteKit-Box2D/Vendor/Box2D/src
```

<img src="SpriteKit-Box2D/Media/Header Search Paths.png" alt="Header Search Paths" style="width:100%;" />

`$(SRCROOT)` means the folder containing the .xcodeproj file, i.e. the outer folder.

### Import Module

If the module map and the paths were right, we should now be able to import Box2D and directly use is inside a swift file!

```swift
import SpriteKit
import Box2D

class MinimalScene: SKScene {
    
    /// Init a Box2D world with a null ID.
    var b2WorldId: b2WorldId = b2_nullWorldId
    
	override func sceneDidLoad() {
        /// Setup scene..
        
        /// Create a Box2D world using the C API.
        var worldDef = b2DefaultWorldDef()
        worldDef.gravity = b2Vec2(x: 0, y: 0)
        b2WorldId = b2CreateWorld(&worldDef)
    }
    
    override func update(_ currentTime: TimeInterval) {
        /// Run Box2D with a fixed timestep.
        b2World_Step(b2WorldId, 1/60, 4)
    }
    
}
```

### Wrap C with Swift

We can use C methods directly inside Swift code. But raw C types do not always behave like native Swift types. For example, in order to use a Box2D type as a key in a dictionary, the key must conform to the Swift protocol `Hashable`.

```swift
/// Does not compile yet
var indexedEntities: [b2BodyId: SKNode] = [:]
```

The good news is we can add these conformances:

```swift
/**

This conformance is valid because a `b2BodyId` is a handle made of `index1`, `world0`, and `generation`. Two body ids are the same handle when those fields match.

*/
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

/// Now compiles!
var indexedEntities: [b2BodyId: SKNode] = [:]
```

Note how we used `extension` directly on a C type and added Swift code to it! If we do enough of that, we will end up with a Swift wrapper around Box2D. In this SpriteKit-Box2D integration, I kept the wrappers to a minimum. It's up to you to extend further according to your needs and coding style.

### Go Further

Mixing Swift with C is a big topic and this project is a first entry to it. The WWDC 2025 session [Safely mix C, C++, and Swift](https://www.youtube.com/watch?v=fFPq_4_LCqo) covers more details and advanced memory safety feature from Swift 6.2.

## Minimal Setup

To run Box2D with SpriteKit, a scene can be structured as follows:

- Create a Box2D world.
- Create SpriteKit visual nodes. SpriteKit is used for rendering.
- For each visual node, create a Box2D body with a collision shape that represents it in the simulation.
- Link each SpriteKit node to its Box2D body. For example, create an `Entity` struct that references both, then store entities in an array or dictionary.
- Step the Box2D simulation with a fixed timestep, typically 1/60 second.
- Before SpriteKit renders the frame, sync the simulation result back by applying Box2D body transforms to SpriteKit nodes.

For a minimal setup, stepping Box2D directly from SpriteKit `update(_:)` is enough. For a production app, use a fixed-step accumulator so Box2D receives the same timestep even if SpriteKit renders at 60 fps, 120 fps, or with occasional frame drops.

## Update and Fixed Update

A physics engine advances with a given increment of time called a timestep, typically 1/60 second. In Box2D, the method that tells the engine to simulate one additional increment of time is called `step`, and it takes a timestep.

Usually, the goal of the simulation is to stay in sync with real time. 3 seconds of wall-clock time should simulate 3 seconds of physics time. But if we call `step` directly from `update(_:)`, we depend on how steady the render refresh cycle is: a frame may take too long before calling the next update, or the device might be running at 120fps, twice the physics rate.

If we pass the same timestep regardless of rendering speed, we may get slow/fast physics motion depending on update speed. If we pass a variable timestep to the physics engine, we won't get similar results, because a physics solver doesn't yield the same outcome from different increments of time.

We need a fixed update. A fixed update is a function that advances the physics engine using a stable timestep. A common way to implement it is with the accumulator pattern, documented in Glenn Fiedler's famous [Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/) post. It works like this:

- Each render update, calculate how much real time passed since the previous update.
- Add that delta time to an accumulator.
- If the accumulator is greater than or equal to the fixed timestep, run one fixed update.
- Subtract one fixed timestep from the accumulator.
- If the accumulator is still greater than or equal to the fixed timestep, run another fixed update.
- If the accumulator is smaller than the fixed timestep, stop and let the render update continue.

In this pattern, the rendering engine may provide variable time, and the accumulator converts it into fixed physics steps.

With SpriteKit, the implementation looks like this:

```swift
class MyScene: SKScene {

    private let fixedTimestep: TimeInterval = 1 / 60
    private var lastUpdateTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0

    override func update(_ currentTime: TimeInterval) {
        /// Calculate delta time
        guard let lastUpdateTime else {
            lastUpdateTime = currentTime
            return
        }
        let deltaTime = currentTime - lastUpdateTime
        self.lastUpdateTime = currentTime

        /// Accumulate time from display refresh cycle
        accumulatedTime += deltaTime

        /// Run code that updates once per rendered frame
        //..
        
        /// Check if enough real time has passed to run fixed update
        while accumulatedTime >= fixedTimestep {
            /// Run code on fixed time steps
            fixedUpdate(fixedTimestep)
            accumulatedTime -= fixedTimestep
        }
    }
    
    func fixedUpdate(_ fixedTimestep: TimeInterval) {
        /// Run the Box2D simulation with a fixed time increment
        b2DWorld.step(Float(fixedTimestep), subSteps: 4)
    }

}
```

Notice that:

- SpriteKit's `update(_:)` passes the current time, not delta time, so we calculate delta time ourselves.
- Per-frame code can run before or after the fixed update. Choose the order that matches your app.
- Box2D should receive the same fixed timestep each step.

In this project, I call fixed update from didSimulatePhysics, not directly from update(_:). didSimulatePhysics is called after SpriteKit has evaluated actions and simulated its own physics. This lets the app pass SpriteKit action or physics results into Box2D before stepping Box2D, if needed later.

## Timestep

The physics engine doesn't have to run in sync with real-time. We could speed up or slow down the rate at which each step is called, using a time scale parameter:

```swift
class MyScene: SKScene {

    /// 1 = normal speed, 0.5 = slow motion, 2 = fast forward.
    private var timeScale: CGFloat = 1
    
    override func update(_ currentTime: TimeInterval) {
        ///...

        /// Use the time scale for accumulating time
        accumulatedTime += deltaTime * timeScale
        
        ///...
    }
}
```

If we use a time scale of 2, the physics engine will step twice more, i.e. it will simulate 2 seconds in 1 second of real-time. How fast can it get? As fast as the computer can process a step.

What happens if we use a time scale of 0.5 or 0.1? We will get physics at 30fps or 6fps, respectively. The motion will be jagged, unless the rendering engine does visual interpolation between each step ("make up frames"). But we would still get the same result, because the timestep hasn't changed.

What happens if we use different timesteps? 

[TBD]

## Screenshots

A chain of 2000 colliding bodies linked with revolute joints:
<img src="SpriteKit-Box2D/Media/Joints-Mac-2.png" alt="Joints-Mac-2" style="width:100%;" />

A short chain of colliding bodies linked with revolute joints:
<img src="SpriteKit-Box2D/Media/Joints-Mac-1.png" alt="Joints-Mac-1" style="width:100%;" />

5000 colliding bodies falling under gravity:
<img src="SpriteKit-Box2D/Media/Drag-Mac-2.png" alt="Drag-Mac-2" style="width:100%;" />

1500 stacked bodies, one body dragged with a motor joint:
<img src="SpriteKit-Box2D/Media/Drag-Mac-1.png" alt="Drag-Mac-1" style="width:100%;" />

## Videos

- [Falling Chain - 2](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Falling%20Chain%20-%202.mov) (43MB)
- [Falling Chain - 1](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Falling%20Chain%20-%201.mov) (14MB)
- [Long Chain with Revolute Joint - With Self Collision](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Chain%20Revolute%20With%20Collision.mov) (263MB)
- [Long Chain with Revolute Joint - No Self Collision](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Chain%20Revolute%20No%20Collision.mov) (87MB)
- [Chain with Revolute Joint - High Damping - 1](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Chain%20with%20Rovolute%20-%201.mov) (28MB)
- [Chain with Revolute Joints - High Damping - 2](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Chain%20with%20Rovolute%20-%202.mov) (23MB)
- [SpriteKit Noise Field + Box2D](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Noise%20Field.mov) (100MB)
- [Stack with High Restitution](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20High%20Restitution.mov) (83MB)
- [Box2D Explode Effect](https://www.achrafkassioui.com/images/SpriteKit%20-%20Box2D%20v3%20-%20Explode.mov) (113MB)

## Links

- Erin Catto, [Box2D](https://github.com/erincatto/box2d), GitHub repository.
- Luiz Fernando, [SwiftBox2D](https://github.com/LuizZak/SwiftBox2D), a Swift wrapper around Box2D. I used it to kickstart this project, then I removed the dependency and included the Box2D code directly, plus minimal Swift conformance and wrappers.

## References

- Glenn Fiedler, [Fix Your Timestep!](https://gafferongames.com/post/fix_your_timestep/), 2004. Used to setup a fixed update in SpriteKit.
- Erin Catto, [Determinism](https://box2d.org/posts/2024/08/determinism/). Used to setup the Determinism test scene.
- [Modules](https://clang.llvm.org/docs/Modules.html), Clang documentation.
