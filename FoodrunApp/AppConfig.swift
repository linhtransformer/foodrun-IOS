import Foundation

// App-wide constants: legal/support links (App Store guideline 5.1.1 wants the
// privacy policy reachable inside the app) and feature switches for parts that
// aren't backed by the server yet. App Review rejects buttons that do nothing,
// so anything half-built stays switched off until it's real.

enum AppConfig {
    static let privacyURL = URL(string: "https://foodrun.nl/legal/privacy")!
    static let supportEmail = "support@foodrun.nl"
    static let supportURL = URL(string: "mailto:support@foodrun.nl")!
    /// Magic-link / OAuth return address. Must be in GOTRUE_URI_ALLOW_LIST on the VPS.
    static let authCallback = URL(string: "foodrun://auth-callback")!

    enum Features {
        /// Shift checklists (Tasks tab, hero checklist chip, shift-detail gate).
        /// Workers can't read `tasks` yet (RLS) — see SchemaContract.md → TasksStore.
        static let checklists = false
        /// Operator-assigned crew tasks (Tasks tab, real data) and the event
        /// screen (briefing / dishes / prep / stock) — HQ migration
        /// 20261008120000_crew_app_event_content. Replaces the sample checklist.
        static let crewTasks = true
        /// "Request a swap" — needs a swap-request table + operator review in HQ.
        static let shiftSwaps = false
        /// "Continue with Google" — needs GOTRUE_EXTERNAL_GOOGLE_ENABLED on the VPS.
        static let googleSignIn = true
        /// Sign in with Apple — needs GOTRUE_EXTERNAL_APPLE_ENABLED + the
        /// "Sign In with Apple" capability on the Xcode target.
        static let appleSignIn = true
    }
}
