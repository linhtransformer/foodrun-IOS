import SwiftUI

// Foodrun motion presets. House easing is cubic-bezier(0.22, 1, 0.36, 1).
// Bundle §Motion.

public enum FRAnimation {
    /// Cubic-bezier(0.22, 1, 0.36, 1) — the house curve for all directional motion.
    public static func house(_ duration: Double) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }

    /// .pressable() scale/color transition
    public static let press: Animation = .spring(response: 0.28, dampingFraction: 0.7)
    /// Cards sliding in, sheets presenting
    public static let enter: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    /// Fade-outs, dismissals
    public static let exit: Animation = .easeIn(duration: 0.18)
    /// Attention-grabbing changes (shift status flip)
    public static let emphasis: Animation = .spring(response: 0.55, dampingFraction: 0.6)
    /// State transitions inside a card
    public static let subtle: Animation = .easeInOut(duration: 0.22)

    // Worker-app additions (bundle §Motion).
    public static let weekStep: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.32)
    public static let monthStep: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.30)
    public static let dayFade: Animation = .easeInOut(duration: 0.20)
    public static let ctaPress: Animation = .easeOut(duration: 0.18)
    public static let neuPress: Animation = .easeOut(duration: 0.16)
    public static let progressGrow: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.30)
    public static let nfcResultRise: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.32)
    public static let nfcBadgePop: Animation = .spring(response: 0.42, dampingFraction: 0.55)
    public static let nfcPulse: Animation = .easeOut(duration: 1.8).repeatForever(autoreverses: false)
    public static let checklistBar: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.30)
    public static let clockTick: Animation = .linear(duration: 1.0)
}
