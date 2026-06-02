/**
 
 # Home View
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 1 Jun 2026
 
 */
import SwiftUI
import SpriteKit

// MARK: View

struct Home: View {
    let uiPadding: CGFloat = 10

    @State var scene: SpriteKit_Box2D.Scene = Scene()
    @State private var isPresetMenuOpen = false
    
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
                Presets.weldStack(scene)
            }
            .onTapGesture {
                isPresetMenuOpen = false
            }
            
            VStack {
                HStack {
                    CameraCapsule(scene: scene)
                    
                    Spacer()
                    
                    PresetMenu(scene: scene, isOpen: $isPresetMenuOpen)
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
            .padding(.top, uiPadding)
            .padding(.bottom, uiPadding)
            .padding(.leading, uiPadding)
            .padding(.trailing, uiPadding)
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
    
    @Binding var isOpen: Bool
    
    var body: some View {
        Button(action: {
            isOpen.toggle()
        }, label: {
            Label("Presets", systemImage: "shippingbox.fill")
                .frame(height: 40)
                .padding(.horizontal, 16)
                .contentShape(Capsule())
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(radius: 10, y: 5)
                }
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
        })
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    presetButton("Stack") {
                        Presets.stack(scene)
                    }
                    
                    presetButton("Pyramid") {
                        Presets.pyramid(scene)
                    }
                    
                    Divider()
                    
                    presetButton("Welded Blocks") {
                        Presets.weldStack(scene)
                    }
                    
                    presetButton("Vertical Chain") {
                        Presets.verticalChain(scene)
                    }
                    
                    presetButton("Horizontal Chain") {
                        Presets.horizontalChain(scene)
                    }
                    
                    Divider()
                    
                    presetButton("Big Pile") {
                        Presets.bigPile(scene)
                    }
                }
                .padding(.vertical, 8)
                .frame(width: 190)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .shadow(radius: 10, y: 5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                }
                .offset(y: 48)
                .zIndex(10)
            }
        }
    }
    
    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            isOpen = false
            action()
        }, label: {
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
    }
}

// MARK: Presets
/**
 
 Tweak the values of the presets here.
 Or navigate to the factory functions and change them directly.
 
 */
enum Presets {
    
    static func stack(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityY: -10)
        scene.createGround(width: 2000)
        scene.createStack(columns: 4, rows: 6, startY: -180)
    }
    
    static func pyramid(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityY: -10)
        scene.createGround(width: 2000)
        scene.createPyramid(baseCount: 7, startY: -200)
    }
    
    static func bigPile(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityY: -10)
        scene.createWalls(width: 10000)
        scene.createBigPile(columns: 10, rows: 700, startY: 500)
    }
    
    static func weldStack(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityY: -10)
        scene.createWalls(width: 2000)
        scene.createWeldJoints(columns: 4, rows: 4, drawJoints: true)
    }
    
    static func verticalChain(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityY: -10)
        scene.createGround(width: 2000)
        scene.createVerticalChain(linkCount: 1000, startY: -400, drawJoints: false)
    }
    
    static func horizontalChain(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityY: -10)
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
                .shadow(radius: 10, y: 5)
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .buttonStyle(.plain)
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
            //.padding(.vertical, 10)
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
