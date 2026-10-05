import Foundation

// In-app language (Me → Language). SwiftUI `Text` follows the
// `.environment(\.locale, FRLanguage.locale)` set at the root; strings built in
// code and every date / number format go through `locale` / `string(_:)` here so
// they switch with it. The choice is also written to AppleLanguages, so system UI
// (permission prompts, the NFC scan sheet) follows on the next launch.

public enum FRLanguage: String, CaseIterable, Identifiable {
    case system, en, nl

    public var id: String { rawValue }

    public static let storageKey = "appLanguage"

    public static var current: FRLanguage {
        FRLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    public static func set(_ language: FRLanguage) {
        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: storageKey)
        if language == .system {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    /// The localization actually shown: the explicit choice, or the best match
    /// for the phone's languages.
    public static var resolvedCode: String {
        switch current {
        case .en: return "en"
        case .nl: return "nl"
        case .system:
            let preferred = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
            return Bundle.preferredLocalizations(from: ["en", "nl"], forPreferences: preferred).first ?? "en"
        }
    }

    /// Dutch formatting for NL; British English otherwise (24-hour clock, "Mon 5 Oct").
    public static var locale: Locale {
        Locale(identifier: resolvedCode == "nl" ? "nl_NL" : "en_GB")
    }

    private static var bundle: Bundle {
        Bundle.main.path(forResource: resolvedCode, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }

    /// Localized string for code that can't use `Text(LocalizedStringKey)`.
    public static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Localized format with plural rules from Localizable.stringsdict.
    public static func string(_ key: String, _ count: Int) -> String {
        String(format: string(key), locale: locale, count)
    }

    /// "7,5 u" / "7.5 h".
    public static func hours(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return "\(f.string(from: value as NSNumber) ?? "0") \(string("unit.hours"))"
    }

    /// Name shown in the language picker. Language names are written in their
    /// own language, like iOS does.
    public var displayName: String {
        switch self {
        case .system: return FRLanguage.string("profile.language.system")
        case .en: return "English"
        case .nl: return "Nederlands"
        }
    }
}
