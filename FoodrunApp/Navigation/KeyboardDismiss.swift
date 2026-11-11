import SwiftUI
import UIKit

/// Tapping anywhere outside a text field closes the keyboard, on every screen and sheet
/// (SwiftUI sheets live in the same window). The tap still reaches whatever is under the
/// finger, so a button pressed while typing closes the keyboard and does its job too.
/// Tapping into another field keeps the keyboard up.
struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let window,
                  !(window.gestureRecognizers ?? []).contains(where: { $0 is DismissKeyboardTap })
            else { return }
            window.addGestureRecognizer(DismissKeyboardTap())
        }
    }
}

final class DismissKeyboardTap: UITapGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(fire))
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    @objc private func fire() {
        view?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }
}
