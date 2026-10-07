import AuthenticationServices
import SwiftUI

// "Continue with Apple" + "Continue with Google", shared by the login and
// sign-up pages. Both use the same height, font and label size so they read as
// a pair. The Apple one is a custom button (Apple's HIG allows it: Apple logo,
// an approved title, black fill, same size as the other buttons) running the
// same ASAuthorization request the system SignInWithAppleButton would; the
// system button sizes its title itself, which never matched the Google one.

struct SocialSignInButtons: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var apple = AppleSignInLauncher()

    var body: some View {
        VStack(spacing: 10) {
            if AppConfig.Features.appleSignIn {
                Button {
                    Task {
                        let result = await apple.run(prepare: auth.prepareAppleRequest)
                        await auth.completeAppleSignIn(result)
                    }
                } label: {
                    label("auth.apple") {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18, weight: .medium))
                            .offset(y: -1)
                    }
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Color.black))
                }
                .buttonStyle(.plain)
            }
            if AppConfig.Features.googleSignIn {
                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    label("auth.google") {
                        Image("google-g").resizable().scaledToFit()
                    }
                    .foregroundStyle(Color.foodrun.foreground)
                    .background(Capsule().fill(Color.foodrun.surface))
                    .overlay(Capsule().stroke(Color.foodrun.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label<Icon: View>(_ title: LocalizedStringKey, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 10) {
            icon().frame(width: 18, height: 18)
            Text(title)
        }
        .font(.system(size: 15, weight: .medium))
        .frame(maxWidth: .infinity, minHeight: 54)
        .contentShape(Capsule())
    }
}

/// "—— or ——" line above the social buttons.
struct AuthOrDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.foodrun.border).frame(height: 1)
            Text("auth.or")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Rectangle().fill(Color.foodrun.border).frame(height: 1)
        }
    }
}

/// Black full-width capsule with a spinner while the request runs.
struct AuthPrimaryButton: View {
    let title: LocalizedStringKey
    let working: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
            FRHaptic.medium.fire()
        } label: {
            ZStack {
                if working {
                    ProgressView().tint(Color.foodrun.backgroundInverseInk)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.foodrun.backgroundInverseInk)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(Color.foodrun.foreground))
            .frCTAShadow()
        }
        .buttonStyle(.plain)
    }
}

/// Runs a Sign in with Apple request without the system button and hands back
/// the same Result that SignInWithAppleButton's onCompletion gets.
final class AppleSignInLauncher: NSObject, ASAuthorizationControllerDelegate,
                                 ASAuthorizationControllerPresentationContextProviding {
    private var controller: ASAuthorizationController?
    private var continuation: CheckedContinuation<Result<ASAuthorization, Error>, Never>?

    @MainActor
    func run(prepare: (ASAuthorizationAppleIDRequest) -> Void) async -> Result<ASAuthorization, Error> {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        prepare(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }

    private func finish(_ result: Result<ASAuthorization, Error>) {
        continuation?.resume(returning: result)
        continuation = nil
        controller = nil
    }
}
