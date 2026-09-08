import SwiftUI

// The Foodrun signature CTA. Near-black fill, white text, pill shape,
// layered black-glow shadow, medium haptic on tap. Full-width by default.

public struct FRPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false

    @Environment(\.frHapticsEnabled) private var hapticsEnabled

    public init(_ title: String, isLoading: Bool = false, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: {
            guard !isDisabled, !isLoading else { return }
            if hapticsEnabled { FRHaptic.medium.fire() }
            action()
        }) {
            ZStack {
                Capsule()
                    .fill(Color.foodrun.foreground)
                    .frCTAShadow()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.foodrun.surface)
                } else {
                    Text(title)
                        .font(Font.foodrun.body.weight(.semibold))
                        .foregroundStyle(Color.foodrun.surface)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .pressable()
        .disabled(isDisabled || isLoading)
    }
}

#Preview {
    VStack(spacing: 16) {
        FRPrimaryButton("Verstuur magische link") {}
        FRPrimaryButton("Laden…", isLoading: true) {}
        FRPrimaryButton("Uitgeschakeld", isDisabled: true) {}
    }
    .padding()
    .background(Color.foodrun.background)
}
