/**
 
 # Home View
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 31 May 2026
 
 */
import SwiftUI
import SpriteKit

// MARK: View

struct Home: View {
    @State var scene: SpriteKit_Box2D.Scene = Scene()
    
    /// SwiftUI doesn't account for title bar in macOS (?!)
    private var titleBarHeight: CGFloat {
#if os(macOS)
        32
#elseif targetEnvironment(macCatalyst)
        32
#else
        0
#endif
    }
    
    var body: some View {
        ZStack {
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: 120,
                options: [.ignoresSiblingOrder],
                debugOptions: [.showsFPS, .showsNodeCount, .showsDrawCount]
            )
            .ignoresSafeArea()
            .onAppear {
                Presets.stack(scene)
            }
            
            GeometryReader { geometry in
                let edgePadding: CGFloat = 10
                let topPadding: CGFloat = edgePadding// + titleBarHeight
                let bottomPadding: CGFloat = edgePadding
                let leadingPadding: CGFloat = edgePadding
                let trailingPadding: CGFloat = edgePadding
                
                VStack {
                    HStack {
                        CameraCapsule(scene: scene)
                        
                        Spacer()
                        
                        PresetMenu(scene: scene)
                    }
                    
                    Spacer()
                    
                    HStack {
                        ToggleButton(
                            isOn: scene.enableDrag,
                            onText: "Dragging ON",
                            offText: "Dragging OFF",
                            onSystemImage: "hand.draw.fill",
                            offSystemImage: "hand.raised.fill",
                            action: {
                                scene.enableDrag.toggle()
                                if !scene.enableDrag {
                                    scene.endDrags(wakeAttached: true)
                                }
                            }
                        )
                        
                        Spacer()
                    }
                }
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .padding(.leading, leadingPadding)
                .padding(.trailing, trailingPadding)
            }
        }
        .background(.black)
    }
}

#Preview {
    Home()
}

// MARK: Preset Menu

struct PresetMenu: View {
    let scene: SpriteKit_Box2D.Scene
    
    var body: some View {
        Menu {
            Button(action: {
                Presets.stack(scene)
            }, label: {
                Text("Stack")
            })
            
            Button(action: {
                Presets.pile(scene)
            }, label: {
                Text("Pile")
            })
            
            Button(action: {
                Presets.largePile(scene)
            }, label: {
                Text("Large Pile")
            })
            
            Button(action: {
                Presets.weldStack(scene)
            }, label: {
                Text("Welded Blocks")
            })
            
            Divider()
            
            Button(action: {
                Presets.verticalChain(scene)
            }, label: {
                Text("Vertical Chain")
            })
            
            Button(action: {
                Presets.horizontalChain(scene)
            }, label: {
                Text("Horizontal Chain")
            })
            
        } label: {
            Label("Presets", systemImage: "shippingbox.fill")
                .lineLimit(1)
                .frame(height: 40)
                .padding(.horizontal, 16)
                .contentShape(Capsule())
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .shadow(radius: 10, y: 5)
    }
}

// MARK: Presets

enum Presets {
    
    static func stack(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createGround(width: 2000)
        scene.createStack(columns: 4, rows: 6, startY: -180)
    }
    
    static func pile(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createGround(width: 2000)
        scene.createPile(baseCount: 5, startY: 100)
    }
    
    static func largePile(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createWalls(width: 10000)
        scene.createLargePile(columns: 10, rows: 500, startY: 500)
        scene.enableDrag = false
    }
    
    static func weldStack(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createWalls(width: 2000)
        scene.createWeldJoints(drawJoints: true)
    }
    
    static func verticalChain(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createGround(width: 2000)
        scene.createVerticalChain(linkCount: 200, startY: -400, drawJoints: true)
    }
    
    static func horizontalChain(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createWalls(width: 1000)
        scene.createHorizontalChain(links: 10, linksShouldCollideWithEachOther: true, drawJoints: true)
    }
    
}

// MARK: Camera Capsule

struct CameraCapsule: View {
    let scene: SpriteKit_Box2D.Scene
    
    var body: some View {
        HStack(spacing: 0) {
            /// Zoom out
            Button(action: {
                let zoomFactor: CGFloat = 1.25
                
                scene.navCamera.setTo(
                    xScale: scene.navCamera.xScale * zoomFactor,
                    yScale: scene.navCamera.yScale * zoomFactor
                )
            }, label: {
                Image(systemName: "minus")
                    .frame(width: 52, height: 40)
                    .contentShape(Rectangle())
            })
            
            Divider()
                .frame(height: 22)
            
            /// Tap to reset zoom
            /// Double tap to reset camera
            Text(String(scene.cameraZoomPercent) + "%")
                .lineLimit(1)
                .frame(width: 70, height: 40)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    scene.navCamera.reset()
                }
                .onTapGesture(count: 1) {
                    scene.navCamera.setTo(
                        xScale: 1,
                        yScale: 1
                    )
                }
            
            Divider()
                .frame(height: 22)
            
            /// Zoom in
            Button(action: {
                let zoomFactor: CGFloat = 0.8
                
                scene.navCamera.setTo(
                    xScale: scene.navCamera.xScale * zoomFactor,
                    yScale: scene.navCamera.yScale * zoomFactor
                )
            }, label: {
                Image(systemName: "plus")
                    .frame(width: 52, height: 40)
                    .contentShape(Rectangle())
            })
        }
        .foregroundStyle(.primary)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .buttonStyle(.plain)
        .shadow(radius: 10, y: 5)
    }
}

// MARK: Toggle Button

struct ToggleButton: View {
    let isOn: Bool
    let onText: String
    let offText: String
    let onSystemImage: String
    let offSystemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action, label: {
            Group {
                if onText.isEmpty && offText.isEmpty {
                    Image(systemName: isOn ? onSystemImage : offSystemImage)
                } else {
                    Label(
                        isOn ? onText : offText,
                        systemImage: isOn ? onSystemImage : offSystemImage
                    )
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(isOn ? .white : .primary)
            .frame(minWidth: 32, minHeight: 40)
            .padding(.horizontal, 16)
            //            .padding(.vertical, 10)
            .background {
                if isOn {
                    Capsule()
                        .fill(.green.opacity(0.75))
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            }
        })
        .buttonStyle(.plain)
    }
}
