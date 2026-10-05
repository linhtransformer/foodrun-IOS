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
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var status: Status = .idle
    @Published var mode: Mode = .password
    @Published var passwordSubmode: PasswordSubmode = .signIn

    private var authStateTask: Task<Void, Never>?

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
                    if let email = change.session?.user.email {
                        await MainActor.run { self.state = .signedIn(email: email) }
                    }
                case .signedOut:
                    await MainActor.run { self.state = .signedOut }
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
            try await client.auth.signInWithOTP(
                email: email.trimmed,
                redirectTo: URL(string: "foodrun://auth-callback")
            )
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
                redirectTo: URL(string: "foodrun://auth-callback")
            )
            if response.session == nil {
                status = .signUpConfirmationSent
            } else {
                status = .idle
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Deep link + sign out

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

    func reset() {
        status = .idle
    }

    // MARK: - Validation

    private func validate(email: String, password: String? = nil) -> Bool {
        let trimmed = email.trimmed
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            status = .failed(String(localized: "auth.error.invalidEmail"))
            return false
        }
        if let password {
            guard password.count >= 8 else {
                status = .failed(String(localized: "auth.error.passwordTooShort"))
                return false
            }
        }
        return true
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
