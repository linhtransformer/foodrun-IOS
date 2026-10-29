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

    /// Set while the user logs out or deletes their account, so a signedOut
    /// event from anything else (the server refusing the refresh token, e.g.
    /// after a password reset) can be explained on the login screen.
    private var expectingSignOut = false

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
                        let wasSignedIn: Bool
                        if case .signedIn = self.state { wasSignedIn = true } else { wasSignedIn = false }
                        if wasSignedIn && !self.expectingSignOut {
                            self.status = .failed(FRLanguage.string("auth.sessionExpired"))
                        }
                        self.expectingSignOut = false
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
            status = .failed(Self.friendly(error))
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
            status = .failed(Self.friendly(error))
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
            status = .failed(Self.friendly(error))
        }
    }

    /// Send the sign-up confirmation email again (Check your email → "Send again").
    func resendConfirmation(email: String) async -> Bool {
        do {
            try await client.auth.resend(email: email.trimmed, type: .signup, emailRedirectTo: AppConfig.authCallback)
            return true
        } catch {
            return false
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
            status = .failed(Self.friendly(error))
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
            status = .failed(Self.friendly(error))
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
            status = .failed(Self.friendly(error))
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
            print("Apple sign-in failed (Apple sheet): \(error)")
            status = .failed(Self.friendly(error))
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
                print("Apple sign-in failed (Supabase id-token exchange): \(error)")
                status = .failed(Self.friendly(error))
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
                status = .failed(Self.friendly(error))
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
        expectingSignOut = true
        try? await client.auth.signOut()
    }

    /// App Store guideline 5.1.1(v): in-app account deletion. Calls the HQ edge
    /// function `delete-my-account` (removes this login's employee links and the
    /// auth user), then clears the local session.
    func deleteAccount() async -> Bool {
        status = .working
        do {
            try await client.functions.invoke("delete-my-account", options: FunctionInvokeOptions(method: .post))
            expectingSignOut = true
            try? await client.auth.signOut(scope: .local)
            status = .idle
            return true
        } catch {
            status = .failed(Self.friendly(error))
            return false
        }
    }

    func reset() {
        status = .idle
    }

    /// The auth server's English messages, in words a crew member can act on (NL / EN).
    /// Anything unknown keeps the server's text, so nothing is hidden.
    static func friendly(_ error: Error) -> String {
        if error is URLError { return FRLanguage.string("auth.error.network") }
        let raw = (String(describing: error) + " " + error.localizedDescription).lowercased()
        let map: [(String, String)] = [
            ("invalid login credentials", "auth.error.invalidLogin"),
            ("invalid_credentials", "auth.error.invalidLogin"),
            ("email not confirmed", "auth.error.notConfirmed"),
            ("email_not_confirmed", "auth.error.notConfirmed"),
            ("user already registered", "auth.error.alreadyRegistered"),
            ("user_already_exists", "auth.error.alreadyRegistered"),
            ("rate limit", "auth.error.tooMany"),
            ("over_email_send_rate_limit", "auth.error.tooMany"),
            ("over_request_rate_limit", "auth.error.tooMany"),
            ("weak_password", "auth.error.weakPassword"),
            ("password should be", "auth.error.weakPassword"),
            ("same_password", "auth.error.samePassword"),
            ("token has expired", "auth.error.codeExpired"),
            ("otp_expired", "auth.error.codeExpired"),
        ]
        for (needle, key) in map where raw.contains(needle) { return FRLanguage.string(key) }
        return error.localizedDescription
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
