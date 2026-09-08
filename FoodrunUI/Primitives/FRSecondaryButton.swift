import SwiftUI

// Outlined variant. Same shape, transparent fill, foreground border.

public struct FRSecondaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.frHapticsEnabled) private var hapticsEnabled

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: {
            if hapticsEnabled { FRHaptic.light.fire() }
            action()
        }) {
            Text(title)
                .font(Font.foodrun.body.weight(.medium))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    Capsule().stroke(Color.foodrun.foreground, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .pressable()
    }
}

#Preview {
    FRSecondaryButton("Terug") {}
        .padding()
        .background(Color.foodrun.background)
}
