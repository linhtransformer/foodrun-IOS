import SwiftUI

// Password reset without deep links: email → 6-digit code from the email →
// (signed in) → choose a new password. The code arrives via Supabase's
// "Reset password" template, which must contain {{ .Token }} — see
// XCODE_SETUP.md → Auth providers.

/// Step 1 + 2, shown as a sheet from the login screen.
struct PasswordResetSheet: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var code: String = ""
    @State private var codeSent = false

    init(initialEmail: String) {
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("auth.reset.title")
                    .font(.system(size: 24, weight: .bold))
                Text(codeSent ? "auth.reset.enterCode" : "auth.reset.intro")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)

                AuthField(label: "auth.email") {
                    TextField("auth.email", text: $email,
                              prompt: Text(verbatim: FRLanguage.string("auth.email.placeholder")))
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(codeSent)
                }

                if codeSent {
                    AuthField(label: "auth.reset.code") {
                        TextField("123456", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    }
                }

                AuthStatusBanner(status: auth.status)

                Button {
                    Task {
                        if codeSent {
                            if await auth.verifyResetCode(email: email, code: code) { dismiss() }
                        } else {
                            await auth.sendPasswordReset(email: email)
                            if auth.status == .resetCodeSent { codeSent = true }
                        }
                    }
                } label: {
                    ZStack {
                        if auth.status == .working {
                            ProgressView().tint(Color.foodrun.backgroundInverseInk)
                        } else {
                            Text(codeSent ? "auth.reset.verify" : "auth.reset.send")
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(Color.foodrun.foreground))
                }
                .buttonStyle(.plain)
                .disabled(auth.status == .working)

                if codeSent {
                    Button {
                        Task { await auth.sendPasswordReset(email: email) }
                    } label: {
                        Text("auth.reset.resend")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.foodrun.foreground)
                            .underline()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
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
