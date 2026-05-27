/**
 
 # Home View
 
 Achraf Kassioui
 Created 19 May 2026
 Updated 23 May 2026
 
 */
import SwiftUI
import SpriteKit

// MARK: View

struct Home: View {
    @State var scene: SpriteKit_Box2D.Scene = Scene()
    
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
            
            VStack {
                HStack{
                    Group {
                        /// Zoom out
                        Button(action: {
                            let zoomFactor: CGFloat = 1.25
                            
                            scene.navCamera.setTo(
                                xScale: scene.navCamera.xScale * zoomFactor,
                                yScale: scene.navCamera.yScale * zoomFactor
                            )
                        }, label: {
                            Image(systemName: "minus")
                                .frame(width: 20, height: 20)
                        })
                        
                        /// Reset zoom to 1:1
                        Button(action: {
                            scene.navCamera.setTo(
                                xScale: 1,
                                yScale: 1
                            )
                        }, label: {
                            Text("\(scene.cameraZoomPercent)%")
                                .frame(width: 50, height: 20)
                        })
                        
                        /// Zoom in
                        Button(action: {
                            let zoomFactor: CGFloat = 0.8
                            
                            scene.navCamera.setTo(
                                xScale: scene.navCamera.xScale * zoomFactor,
                                yScale: scene.navCamera.yScale * zoomFactor
                            )
                        }, label: {
                            Image(systemName: "plus")
                                .frame(width: 20, height: 20)
                        })
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.5))
                    .shadow(radius: 10, y: 5)

                    
                    Spacer()
                    
                    Group {
                        /// Presets
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
                                Presets.weldStack(scene)
                            }, label: {
                                Text("Weld Stack")
                            })
                            
                            Button(action: {
                                Presets.verticalChain(scene)
                            }, label: {
                                Text("Vertical Chain")
                            })
                        } label: {
                            Label("Presets", systemImage: "shippingbox.fill")
                                .frame(width: 100, height: 20)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.5))
                    .shadow(radius: 10, y: 5)
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
            .padding()
        }
        .background(.black)
    }
}

#Preview {
    Home()
}

// MARK: Presets

enum Presets {
    
    static func pile(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createGround()
        scene.createPile(baseCount: 12, startY: -260)
    }
    
    static func stack(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createGround()
        scene.createStack(columns: 4, rows: 6, startY: -180)
    }
    
    static func weldStack(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createWalls()
        scene.createWeldJoints(drawJoints: true)
    }
    
    static func verticalChain(_ scene: SpriteKit_Box2D.Scene) {
        scene.removeContent()
        scene.setupBox2D(gravityLength: -10)
        scene.createGround()
        scene.createVerticalChain(linkCount: 200, startY: -400, drawJoints: true)
    }
    
}
