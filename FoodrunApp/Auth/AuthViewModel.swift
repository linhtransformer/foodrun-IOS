import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(email: String)
    }

    enum Mode: String, CaseIterable, Identifiable {
        case password = "Wachtwoord"
        case magicLink = "Magische link"
        var id: String { rawValue }
    }

    enum PasswordSubmode: String, CaseIterable, Identifiable {
        case signIn = "Log in"
        case signUp = "Registreer"
        var id: String { rawValue }
    }

    enum Status: Equatable {
        case idle
        case working
        case magicLinkSent
        case signUpConfirmationSent
        case resetCodeSent
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var status: Status = .idle
    @Published var mode: Mode = .password
    @Published var passwordSubmode: PasswordSubmode = .signIn
    /// Set after a password-reset code is verified: the user is signed in but
    /// must choose a new password before the app opens (RootView).
    @Published private(set) var mustSetNewPassword = false

    private var authStateTask: Task<Void, Never>?
    /// Raw nonce for the Sign in with Apple request in flight.
    private var appleNonce: String?

    private var client: SupabaseClient { SupabaseManager.shared.client }

    func bootstrap() async {
        do {
            let session = try await client.auth.session
            state = .signedIn(email: session.user.email ?? "")
        } catch {
            state = .signedOut
        }

        authStateTask?.cancel()
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await change in self.client.auth.authStateChanges {
                switch change.event {
                case .signedIn, .tokenRefreshed:
                    if let session = change.session {
                        await MainActor.run { self.state = .signedIn(email: session.user.email ?? "") }
                    }
                case .signedOut:
                    await MainActor.run {
                        self.state = .signedOut
                        self.mustSetNewPassword = false
                    }
                default:
                    break
                }
            }
        }
    }

    // MARK: - Magic link

    func sendMagicLink(email: String) async {
        guard validate(email: email) else { return }
        status = .working
        do {
            try await client.auth.signInWithOTP(email: email.trimmed, redirectTo: AppConfig.authCallback)
            status = .magicLinkSent
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Password

    func signIn(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }
        status = .working
        do {
            _ = try await client.auth.signIn(email: email.trimmed, password: password)
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func signUp(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }
        status = .working
        do {
            let response = try await client.auth.signUp(
                email: email.trimmed,
                password: password,
                redirectTo: AppConfig.authCallback
            )
            status = response.session == nil ? .signUpConfirmationSent : .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Password reset (6-digit code by email)
    //
    // No deep link needed: Supabase mails a one-time code ({{ .Token }} in the
    // "Reset password" template), the user types it here, which signs them in,
    // then they pick a new password. Mail goes out through the VPS SMTP
    // (Resend) — see XCODE_SETUP.md → Auth providers.

    func sendPasswordReset(email: String) async {
        guard validate(email: email) else { return }
        status = .working
        do {
            try await client.auth.resetPasswordForEmail(email.trimmed, redirectTo: AppConfig.authCallback)
            status = .resetCodeSent
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Returns true when the code was accepted (the user is now signed in and
    /// RootView shows the new-password screen).
    func verifyResetCode(email: String, code: String) async -> Bool {
        let token = code.filter(\.isNumber)
        guard token.count >= 6 else {
            status = .failed(FRLanguage.string("auth.reset.codeInvalid"))
            return false
        }
        status = .working
        mustSetNewPassword = true
        do {
            _ = try await client.auth.verifyOTP(email: email.trimmed, token: token, type: .recovery)
            status = .idle
            return true
        } catch {
            mustSetNewPassword = false
            status = .failed(error.localizedDescription)
            return false
        }
    }

    func setNewPassword(_ password: String) async {
        guard password.count >= 8 else {
            status = .failed(FRLanguage.string("auth.error.passwordTooShort"))
            return
        }
        status = .working
        do {
            _ = try await client.auth.update(user: UserAttributes(password: password))
            mustSetNewPassword = false
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Sign in with Apple (native sheet → Supabase id-token sign-in)

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // The user closing the sheet isn't an error worth showing.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            status = .failed(error.localizedDescription)
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce else {
                status = .failed(FRLanguage.string("auth.error.apple"))
                return
            }
            status = .working
            do {
                _ = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
                )
                // Apple only shares the name on the very first sign-in — keep it.
                let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                if !name.isEmpty {
                    _ = try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(name), "name": .string(name)]))
                }
                status = .idle
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Google (Supabase OAuth in an in-app browser sheet)

    func signInWithGoogle() async {
        status = .working
        do {
            // supabase-swift opens ASWebAuthenticationSession (in-app, not Safari —
            // App Review rejects bouncing users out to Safari) and returns here
            // through foodrun://auth-callback.
            _ = try await client.auth.signInWithOAuth(provider: .google, redirectTo: AppConfig.authCallback)
            status = .idle
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                status = .idle
            } else {
                status = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Deep link + sign out + delete

    func handleDeepLink(_ url: URL) async {
        do {
            try await client.auth.session(from: url)
        } catch {
            print("Deep link session error: \(error)")
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    /// App Store guideline 5.1.1(v): in-app account deletion. Calls the HQ edge
    /// function `delete-my-account` (removes this login's employee links and the
    /// auth user), then clears the local session.
    func deleteAccount() async -> Bool {
        status = .working
        do {
            try await client.functions.invoke("delete-my-account", options: FunctionInvokeOptions(method: .post))
            try? await client.auth.signOut(scope: .local)
            status = .idle
            return true
        } catch {
            status = .failed(error.localizedDescription)
            return false
        }
    }

    func reset() {
        status = .idle
    }

    // MARK: - Validation

    private func validate(email: String, password: String? = nil) -> Bool {
        let trimmed = email.trimmed
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            status = .failed(FRLanguage.string("auth.error.invalidEmail"))
            return false
        }
        if let password {
            guard password.count >= 8 else {
                status = .failed(FRLanguage.string("auth.error.passwordTooShort"))
                return false
            }
        }
        return true
    }

    // MARK: - Nonce helpers (Sign in with Apple)

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
