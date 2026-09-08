import SwiftUI

// Standard press feedback. Every interactive surface uses this.
// Reduced-motion aware — swaps scale for opacity.

public struct PressableModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? 0.97 : 1.0))
            .opacity(reduceMotion ? (pressed ? 0.8 : 1.0) : 1.0)
            .animation(FRAnimation.press, value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed { pressed = true }
                    }
                    .onEnded { _ in
                        pressed = false
                    }
            )
    }
}

public extension View {
    func pressable() -> some View {
        modifier(PressableModifier())
    }
}
