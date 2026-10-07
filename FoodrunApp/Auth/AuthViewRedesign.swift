import SwiftUI

// Bundle §1 "Sign in (AuthView, revise)". Email + password, then Sign in with
// Apple / Google right under Log in. "Don't have an account?" at the bottom opens
// the separate sign-up page (SignUpView). Delegates to AuthViewModel for the
// Supabase mechanics. "Forgot password?" opens the 6-digit-code reset sheet.

public struct AuthViewRedesign: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var showReset: Bool = false
    @State private var showSignUp: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            login
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showSignUp) {
                    SignUpView()
                }
        }
        .tint(Color.foodrun.foreground)
    }

    private var login: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 0)
                    brand
                    fields
                    statusBanner
                    VStack(spacing: 14) {
                        AuthPrimaryButton(title: "auth.login", working: auth.status == .working) {
                            Task { await auth.signIn(email: email, password: password) }
                        }
                        if AppConfig.Features.appleSignIn || AppConfig.Features.googleSignIn {
                            AuthOrDivider()
                            SocialSignInButtons()
                        }
                    }
                    Spacer(minLength: 16)
                    footer
                }
                .padding(.horizontal, FRSpacing.screenH.value)
                .padding(.top, 8)
                .padding(.bottom, 12)
                // Fill the screen so the spacers can centre the form and pin the
                // footer; it still scrolls once the keyboard takes the space.
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
        .disabled(auth.status == .working)
        .sheet(isPresented: $showReset) {
            PasswordResetSheet(initialEmail: email)
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var brand: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                Image("foodrun-logo")
                    .resizable().scaledToFit()
                    .frame(height: 60)
                Text("Foodrun")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.4)
            }
            Text("auth.headline")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.9)
                .multilineTextAlignment(.center)
            Text("auth.subheadline")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
    }

    private var fields: some View {
        VStack(spacing: 14) {
            AuthField(label: "auth.email") {
                // Verbatim prompt: a LocalizedStringKey would auto-link the address.
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
                            TextField("auth.password.placeholder", text: $password)
                        } else {
                            SecureField("auth.password.placeholder", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .font(.system(size: 15))
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(showPassword ? "auth.password.hide" : "auth.password.show"))
                }
            }
            HStack {
                Spacer()
                Button {
                    auth.reset()
                    showReset = true
                } label: {
                    Text("auth.forgotPassword")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.foodrun.foreground)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        AuthStatusBanner(status: auth.status)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text("auth.noAccount")
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Button {
                    auth.reset()
                    showSignUp = true
                } label: {
                    Text("auth.makeAccount")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foodrun.foreground)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 14))
            Link(destination: AppConfig.privacyURL) {
                Text("legal.privacy")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .underline()
            }
        }
    }
}

// MARK: - Shared auth bits

/// Labelled text-field shell used by the login and reset screens.
struct AuthField<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            content()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.foodrun.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.foodrun.border, lineWidth: 1)
                )
        }
    }
}

/// Error / confirmation line under the auth fields.
struct AuthStatusBanner: View {
    let status: AuthViewModel.Status

    var body: some View {
        switch status {
        case .failed(let message):
            banner(Text(verbatim: message), symbol: "exclamationmark.circle", tint: Color.foodrun.subject.destructive)
        case .signUpConfirmationSent:
            banner(Text("auth.status.confirmEmail"), symbol: "envelope", tint: Color.foodrun.foreground)
        case .magicLinkSent:
            banner(Text("auth.status.magicLinkSent"), symbol: "envelope", tint: Color.foodrun.foreground)
        case .resetCodeSent:
            banner(Text("auth.reset.sent"), symbol: "envelope", tint: Color.foodrun.foreground)
        case .idle, .working:
            EmptyView()
        }
    }

    private func banner(_ text: Text, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
            text.multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(tint)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .transition(.opacity)
    }
}
