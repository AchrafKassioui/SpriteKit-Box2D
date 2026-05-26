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
                    
                    /// Presets
                    Menu {
                        Button(action: {
                            scene.randomPile()
                        }, label: {
                            Text("Random Pile")
                        })
                        
                        Button(action: {
                            scene.gridStack()
                        }, label: {
                            Text("Grid Stack")
                        })
                        
                        Button(action: {
                            scene.verticalChain()
                        }, label: {
                            Text("Vertical Chain")
                        })
                        
                        Button(action: {
                            scene.removeContent()
                        }, label: {
                            Text("Clear")
                        })
                    } label: {
                        Label("Presets", systemImage: "shippingbox.fill")
                            .frame(width: 100, height: 20)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.5))
                    .shadow(radius: 10, y: 5)
                }
                
                Spacer()
                
                HStack {
                    ToggleButton(
                        isOn: scene.enableDrag,
                        onText: "Drag ON",
                        offText: "Drag OFF",
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

extension Scene {
    
    func randomPile() {
        removeContent()
        createGround()
        createBlockGrid(columns: 12, rows: 10, startY: -180, randomRotation: true)
    }
    
    func gridStack() {
        removeContent()
        createGround()
        createBlockGrid(columns: 6, rows: 8, startY: -180, randomRotation: false)
    }
    
    func verticalChain() {
        removeContent()
        createGround()
        createVerticalChain(linkCount: 500, startY: -1800)
    }
    
}
