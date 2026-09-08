import SwiftUI
import UIKit

// Foodrun haptics. First-class part of the design system — every
// interactive primitive fires an appropriate haptic. Silence globally
// with `.environment(\.frHapticsEnabled, false)`.

public enum FRHaptic {
    case light
    case medium
    case rigid
    case success
    case warning
    case error

    public func fire() {
        switch self {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct FRHapticsEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

public extension EnvironmentValues {
    var frHapticsEnabled: Bool {
        get { self[FRHapticsEnabledKey.self] }
        set { self[FRHapticsEnabledKey.self] = newValue }
    }
}

public extension View {
    /// Fires the haptic when `trigger` changes to a new value.
    func frHaptic<V: Equatable>(_ haptic: FRHaptic, on trigger: V) -> some View {
        modifier(HapticOnChangeModifier(haptic: haptic, trigger: trigger))
    }
}

struct HapticOnChangeModifier<V: Equatable>: ViewModifier {
    let haptic: FRHaptic
    let trigger: V
    @Environment(\.frHapticsEnabled) private var enabled

    func body(content: Content) -> some View {
        content.onChange(of: trigger) { _, _ in
            if enabled { haptic.fire() }
        }
    }
}
