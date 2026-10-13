import SwiftUI

// Password reset without deep links, each step its own page: email →
// 6-digit code from the email → (signed in) → choose a new password. The code arrives via Supabase's
// "Reset password" template, which must contain {{ .Token }} — see
// XCODE_SETUP.md → Auth providers.

/// Step 1, a page pushed from the login screen: enter your email, get a code.
struct PasswordResetView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email: String
    @State private var showCode = false

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("auth.reset.title")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.8)
                Text("auth.reset.intro")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)

                AuthField(label: "auth.email") {
                    TextField("auth.email", text: $email,
                              prompt: Text(verbatim: FRLanguage.string("auth.email.placeholder")))
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 15))
                }

                // The "code sent" confirmation belongs on the next page.
                if case .failed = auth.status { AuthStatusBanner(status: auth.status) }

                AuthPrimaryButton(title: "auth.reset.send", working: auth.status == .working) {
                    Task {
                        await auth.sendPasswordReset(email: email)
                        if auth.status == .resetCodeSent { showCode = true }
                    }
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
        .disabled(auth.status == .working)
        .navigationDestination(isPresented: $showCode) {
            PasswordResetCodeView(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        .onAppear { if !showCode { auth.reset() } }
    }
}

/// Step 2, its own page: type the 6-digit code from the email. A correct code
/// signs the user in; RootView then shows NewPasswordView.
struct PasswordResetCodeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    let email: String
    @State private var code: String = ""
    @FocusState private var codeFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("auth.reset.codeTitle")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.8)
                VStack(alignment: .leading, spacing: 4) {
                    Text("auth.reset.enterCode")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    Text(verbatim: email)
                        .font(.system(size: 15, weight: .semibold))
                }

                AuthField(label: "auth.reset.code") {
                    TextField("123456", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        .focused($codeFocused)
                }

                AuthStatusBanner(status: auth.status)

                AuthPrimaryButton(title: "auth.reset.verify", working: auth.status == .working) {
                    Task { _ = await auth.verifyResetCode(email: email, code: code) }
                }

                Button {
                    Task { await auth.sendPasswordReset(email: email) }
                } label: {
                    Text("auth.reset.resend")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.foodrun.foreground)
                        .underline()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
        .disabled(auth.status == .working)
        .onAppear { codeFocused = true }
    }
}

/// Step 3, shown full-screen by RootView while `auth.mustSetNewPassword`.
struct NewPasswordView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var password: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("auth.reset.newTitle")
                .font(.system(size: 26, weight: .bold))
            Text("auth.reset.newIntro")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            AuthField(label: "auth.password") {
                SecureField("auth.password.placeholder", text: $password)
                    .textContentType(.newPassword)
            }
            AuthStatusBanner(status: auth.status)
            Button {
                Task { await auth.setNewPassword(password) }
            } label: {
                Text("auth.reset.save")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(Color.foodrun.foreground))
            }
            .buttonStyle(.plain)
            .disabled(auth.status == .working)
            Spacer()
        }
        .padding(.horizontal, FRSpacing.screenH.value)
        .padding(.top, 80)
        .background(Color.foodrun.background.ignoresSafeArea())
    }
}
