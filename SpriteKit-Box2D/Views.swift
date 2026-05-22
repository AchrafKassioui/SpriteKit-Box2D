/**
 
 # SwiftUI View
 
 Buttons and common views with the very annoying SwiftUI.
 
 Achraf Kassioui
 Created 21 May 2026
 Updated 22 May 2026
 
 */
import SwiftUI

// MARK: Button

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
