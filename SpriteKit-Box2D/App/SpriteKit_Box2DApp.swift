/**
 
 # App
 
 App entry point.
 Use SwiftUI.Scene to disambiguate from the SpriteKit main scene.
 Note: this app module name is `SpriteKit_Box2D`.
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 1 June 2026
 
 */
import SwiftUI

@main
struct SpriteKit_Box2DApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            Home()
        }
    }
}
