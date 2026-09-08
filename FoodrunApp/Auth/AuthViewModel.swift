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

    enum SendStatus: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var sendStatus: SendStatus = .idle

    private var authStateTask: Task<Void, Never>?

    private var client: SupabaseClient { SupabaseManager.shared.client }

    func bootstrap() async {
        // Try to hydrate from stored session.
        do {
            let session = try await client.auth.session
            state = .signedIn(email: session.user.email ?? "")
        } catch {
            state = .signedOut
        }

        // Listen for future auth changes.
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

    func sendMagicLink(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            sendStatus = .failed("Voer een geldig e-mailadres in.")
            return
        }
        sendStatus = .sending
        do {
            try await client.auth.signInWithOTP(
                email: trimmed,
                redirectTo: URL(string: "foodrun://auth-callback")
            )
            sendStatus = .sent
        } catch {
            sendStatus = .failed(error.localizedDescription)
        }
    }

    func handleDeepLink(_ url: URL) async {
        do {
            try await client.auth.session(from: url)
        } catch {
            // Ignore — session listener will surface state on success.
            print("Deep link session error: \(error)")
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func reset() {
        sendStatus = .idle
    }
}
