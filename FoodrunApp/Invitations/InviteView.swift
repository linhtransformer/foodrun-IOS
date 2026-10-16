import SwiftUI

// Shown by RootView when an invite link opens the app (PendingInvite). Steps:
// peek (who invites) → Accept → sign in through the link if there is no session
// → redeem_worker_invite → "Welcome to <organization>". Errors follow the
// table in SchemaContract.md → "Invites by email".

struct InviteView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let token: String

    private enum Phase: Equatable {
        case loading
        case ready
        case working
        case joined(organization: String)
        case failed(String)
        case otherAccount           // invite is for another account than the one signed in
    }

    @State private var phase: Phase = .loading
    @State private var organizationName: String?
    @State private var emailHint: String?

    private var signedIn: Bool {
        if case .signedIn = auth.state { return true }
        return false
    }

    var body: some View {
        AuthCenteredPage {
            VStack(spacing: 18) {
                icon
                content
            }
        }
        .task { await peek() }
        .interactiveDismissDisabled(phase == .working)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var icon: some View {
        let (symbol, fill): (String, Color) = {
            switch phase {
            case .joined: return ("checkmark", Color.foodrun.subject.positive.opacity(0.2))
            case .failed, .otherAccount: return ("exclamationmark", Color.foodrun.subject.warning.opacity(0.2))
            default: return ("envelope.open.fill", Color.foodrun.truck.mees)
            }
        }()
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .semibold))
            .foregroundStyle(Color.foodrun.foreground)
            .frame(width: 80, height: 80)
            .background(Circle().fill(fill))
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView().padding(.top, 8)

        case .ready, .working:
            title(String(format: FRLanguage.string("invite.title %@"), organizationName ?? "Foodrun"))
            if let emailHint {
                body(String(format: FRLanguage.string("invite.forEmail %@"), emailHint))
            }
            body(FRLanguage.string(signedIn ? "invite.bodySignedIn" : "invite.bodySignedOut"))
            AuthPrimaryButton(title: "invite.accept", working: phase == .working) {
                Task { await accept() }
            }
            .padding(.top, 6)
            secondary("invite.notNow") { dismiss() }

        case .joined(let organization):
            title(String(format: FRLanguage.string("invite.welcome %@"), organization))
            body(FRLanguage.string("invite.welcomeBody"))
            AuthPrimaryButton(title: "action.done", working: false) { dismiss() }
                .padding(.top, 6)

        case .otherAccount:
            title(FRLanguage.string("invite.otherAccountTitle"))
            body(FRLanguage.string("invite.otherAccount"))
            AuthPrimaryButton(title: "invite.signOutContinue", working: false) {
                Task {
                    await auth.signOut()
                    await accept()
                }
            }
            .padding(.top, 6)
            secondary("invite.notNow") { dismiss() }

        case .failed(let message):
            title(FRLanguage.string("invite.failedTitle"))
            body(message)
            AuthPrimaryButton(title: "action.close", working: false) { dismiss() }
                .padding(.top, 6)
        }
    }

    private func title(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 26, weight: .bold))
            .tracking(-0.6)
            .multilineTextAlignment(.center)
    }

    private func body(_ text: String) -> some View {
        Text(verbatim: text)
            .frText(FRType.rowSubtitle)
            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
    }

    private func secondary(_ key: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(key)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Flow

    private func peek() async {
        do {
            let r = try await WorkerAPI.peekInvite(token: token)
            organizationName = r.organization_name
            emailHint = r.email_hint
            switch r.state {
            case "open":
                phase = .ready
            case "used":
                phase = .failed(Self.message(for: "invite_used"))
            case "expired":
                phase = .failed(Self.message(for: "invite_expired"))
            default:
                phase = .failed(Self.message(for: r.error ?? "invalid_invite"))
            }
        } catch {
            phase = .failed(FRLanguage.string("invite.error.generic"))
        }
    }

    private func accept() async {
        phase = .working
        do {
            if !signedIn {
                if let code = try await WorkerAPI.signInWithInvite(token: token) {
                    phase = .failed(Self.message(for: code))
                    FRHaptic.error.fire()
                    return
                }
            }
            let joined = try await WorkerAPI.redeemInvite(token: token)
            PendingInvite.shared.markJoined()
            phase = .joined(organization: joined.organization_name)
            FRHaptic.success.fire()
        } catch {
            let raw = String(describing: error) + " " + error.localizedDescription
            if raw.contains("invite_for_other_account") {
                phase = .otherAccount
            } else if let code = ["invalid_invite", "invite_used", "invite_expired", "too_many_sign_ins"]
                        .first(where: raw.contains) {
                phase = .failed(Self.message(for: code))
            } else {
                phase = .failed(FRLanguage.string("invite.error.generic"))
            }
            FRHaptic.error.fire()
        }
    }

    private static func message(for code: String) -> String {
        switch code {
        case "invite_used": return FRLanguage.string("invite.error.used")
        case "invite_expired": return FRLanguage.string("invite.error.expired")
        case "too_many_sign_ins": return FRLanguage.string("invite.error.tooMany")
        case "invalid_invite": return FRLanguage.string("invite.error.invalid")
        default: return FRLanguage.string("invite.error.generic")
        }
    }
}
