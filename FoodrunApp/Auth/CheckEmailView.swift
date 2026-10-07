import SwiftUI

// Shown after "Create account" when Supabase needs the email confirmed first.
// The link in that email opens foodrun://auth-callback, which signs the worker
// in (AuthViewModel.handleDeepLink) — or they confirm and log in by hand.

struct CheckEmailView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.openURL) private var openURL

    let email: String
    var onBackToLogin: () -> Void

    @State private var resending = false
    @State private var resent: Bool?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Color.foodrun.truck.mees))
                    .padding(.top, 40)

                Text("checkEmail.title")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    Text("checkEmail.sentTo")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    Text(verbatim: email)
                        .font(.system(size: 16, weight: .semibold))
                        .textSelection(.enabled)
                }

                Text("checkEmail.body")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)

                VStack(spacing: 10) {
                    AuthPrimaryButton(title: "checkEmail.openMail", working: false) {
                        // Opens the Mail app's inbox.
                        if let url = URL(string: "message://") { openURL(url) }
                    }
                    Button(action: onBackToLogin) {
                        Text("checkEmail.backToLogin")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.foodrun.foreground)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("checkEmail.noEmail")
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        Button {
                            Task { await resend() }
                        } label: {
                            if resending {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("checkEmail.resend")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.foodrun.foreground)
                                    .underline()
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(resending)
                    }
                    .font(.system(size: 14))
                    if let resent {
                        Text(resent ? "checkEmail.resent" : "checkEmail.resendFailed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(resent ? Color.foodrun.foreground : Color.foodrun.subject.destructive)
                    }
                    Text("checkEmail.spamHint")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.bottom, 24)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private func resend() async {
        resending = true
        resent = await auth.resendConfirmation(email: email)
        resending = false
        if resent == true { FRHaptic.success.fire() } else { FRHaptic.error.fire() }
    }
}
