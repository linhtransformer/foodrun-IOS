import SwiftUI

// Ik → Instellingen → Weergave: follow the phone, or always light / dark.
// Stored on the phone; RootView applies it with `.preferredColorScheme`.

public enum FRAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    public var id: String { rawValue }

    public static let storageKey = "appearance"

    /// nil = follow the phone.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public var labelKey: LocalizedStringKey {
        switch self {
        case .system: return "settings.appearance.system"
        case .light: return "settings.appearance.light"
        case .dark: return "settings.appearance.dark"
        }
    }
}
