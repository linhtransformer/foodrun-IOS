import SwiftUI

// "Make an account", pushed from the login screen's "Don't have an account?"
// line. Email + password sign-up (Supabase sends a confirmation email), or
// Apple / Google, which create the account on first use. Once HQ adds the
// worker, the "waiting for your employer" screen (NotLinkedView) clears itself.

struct SignUpView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    /// Set once the confirmation email is out: the form makes way for "Check your email".
    @State private var confirmationSentTo: String?

    var body: some View {
        Group {
            if let confirmationSentTo {
                CheckEmailView(email: confirmationSentTo) {
                    auth.reset()
                    dismiss()
                }
                .transition(.opacity)
            } else {
                form
            }
        }
        .animation(FRAnimation.subtle, value: confirmationSentTo)
        .onChange(of: auth.status) { _, status in
            if status == .signUpConfirmationSent {
                confirmationSentTo = email.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .onAppear { auth.reset() }
        .onDisappear { auth.reset() }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("auth.signUp.title")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                    Text("auth.signUp.intro")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }

                VStack(spacing: 14) {
                    AuthField(label: "auth.email") {
                        TextField("auth.email", text: $email,
                                  prompt: Text(verbatim: FRLanguage.string("auth.email.placeholder")))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                    }
                    AuthField(label: "auth.password") {
                        HStack(spacing: 10) {
                            Group {
                                if showPassword {
                                    TextField("auth.signUp.passwordHint", text: $password)
                                } else {
                                    SecureField("auth.signUp.passwordHint", text: $password)
                                }
                            }
                            .textContentType(.newPassword)
                            .font(.system(size: 15))
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(showPassword ? "auth.password.hide" : "auth.password.show"))
                        }
                    }
                }

                AuthStatusBanner(status: auth.status)

                VStack(spacing: 14) {
                    AuthPrimaryButton(title: "auth.signUp.create", working: auth.status == .working) {
                        Task { await auth.signUp(email: email, password: password) }
                    }
                    if AppConfig.Features.appleSignIn || AppConfig.Features.googleSignIn {
                        AuthOrDivider()
                        SocialSignInButtons()
                    }
                }

                HStack(spacing: 4) {
                    Text("auth.haveAccount")
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    Button { dismiss() } label: {
                        Text("auth.login")
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.foodrun.foreground)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
        .disabled(auth.status == .working)
    }
}
