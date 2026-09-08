import SwiftUI

// Foodrun motion presets. Mirrors spec §5.1.

public enum FRAnimation {
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
}
