//
//  Views.swift
//  SpriteKit-Box2D
//
//  Created by Achraf Kassioui on 21/5/2026.
//

import SwiftUI

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
            .foregroundStyle(isOn ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
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
