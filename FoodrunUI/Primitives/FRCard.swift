import SwiftUI

// Soft-UI card. Tap-aware if `onTap` is provided.

public struct FRCard<Content: View>: View {
    let onTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @Environment(\.frHapticsEnabled) private var hapticsEnabled

    public init(onTap: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.onTap = onTap
        self.content = content
    }

    public var body: some View {
        Group {
            if let onTap {
                Button(action: {
                    if hapticsEnabled { FRHaptic.light.fire() }
                    onTap()
                }) {
                    cardBody
                }
                .buttonStyle(.plain)
                .pressable()
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        content()
            .padding(FRSpacing.lg.value)
            .background(
                RoundedRectangle(cornerRadius: FRRadius.card.value, style: .continuous)
                    .fill(Color.foodrun.card)
            )
            .frNeu(.raised)
    }
}

#Preview {
    FRCard {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kaart titel").font(Font.foodrun.sectionTitle)
            Text("Ondertitel").font(Font.foodrun.caption).foregroundStyle(Color.foodrun.mutedForeground)
        }
    }
    .padding()
    .background(Color.foodrun.background)
}
