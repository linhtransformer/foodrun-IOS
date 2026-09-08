import SwiftUI

// Foodrun shadow token families. Mirrors design-system.md §Shadow.
//
// Two families:
//  * Elevation — popovers, dialogs, toasts. Soft (opacity 0.03-0.14).
//  * Neu — soft-UI raised/pressed cards on the off-white ground.
// Plus the CTA-specific black-pill glow used only by FRPrimaryButton.

public enum FRElevation {
    case pop    // small popovers, tooltips
    case modal  // sheets, dialogs
    case toast  // toasts, snackbars
}

public enum FRNeu {
    case raised
    case raisedLg
    case pressed
    case inset
}

public extension View {
    func frElevation(_ level: FRElevation) -> some View {
        switch level {
        case .pop:
            return AnyView(self.shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2))
        case .modal:
            return AnyView(self.shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 8))
        case .toast:
            return AnyView(self.shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 4))
        }
    }

    func frNeu(_ style: FRNeu) -> some View {
        switch style {
        case .raised:
            return AnyView(
                self
                    .shadow(color: .white.opacity(0.9), radius: 6, x: -3, y: -3)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 4, y: 5)
            )
        case .raisedLg:
            return AnyView(
                self
                    .shadow(color: .white.opacity(0.9), radius: 10, x: -6, y: -6)
                    .shadow(color: .black.opacity(0.08), radius: 14, x: 6, y: 8)
            )
        case .pressed:
            return AnyView(
                self
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: -2, y: -2)
            )
        case .inset:
            return AnyView(self.overlay(
                RoundedRectangle(cornerRadius: FRRadius.card.value, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            ))
        }
    }

    // CTA-specific shadow — used only by FRPrimaryButton.
    func frCTAShadow(hover: Bool = false) -> some View {
        self
            .shadow(color: .black.opacity(hover ? 0.28 : 0.22), radius: hover ? 18 : 12, x: 0, y: hover ? 10 : 6)
            .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
    }
}
