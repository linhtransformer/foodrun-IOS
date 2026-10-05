import SwiftUI

// Bundle §1 "Sign in (AuthView, revise)". Email + password primary, Make-an-account
// secondary, invite-link footer. Delegates to the existing AuthViewModel for
// Supabase mechanics (magic link path still exists in the VM for later).

public struct AuthViewRedesign: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                brand
                fields
                actions
                Spacer(minLength: 16)
                footer
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, 60)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var brand: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                Image("foodrun-logo")
                    .resizable().scaledToFit()
                    .frame(height: 76)
                Text("Foodrun")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.4)
            }
            Text("auth.headline")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.9)
                .multilineTextAlignment(.center)
            Text("auth.subheadline")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.top, 24)
    }

    private var fields: some View {
        VStack(spacing: 14) {
            labeledField(label: "auth.email") {
                // Verbatim prompt: a LocalizedStringKey would auto-link the address.
                TextField("auth.email", text: $email,
                          prompt: Text(verbatim: String(localized: "auth.email.placeholder")))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .font(.system(size: 15))
            }
            labeledField(label: "auth.password") {
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
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func labeledField<Content: View>(label: LocalizedStringKey,
                                             @ViewBuilder content: () -> Content) -> some View {
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

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await auth.signIn(email: email, password: password) }
                FRHaptic.medium.fire()
            } label: {
                Text("auth.login")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .frCTAShadow()
            }.buttonStyle(.plain)

            Button {
                Task { await auth.signUp(email: email, password: password) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("auth.makeAccount")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(maxWidth: .infinity, minHeight: 54)
                .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
            }.buttonStyle(.plain)
        }
    }

    private var footer: some View {
        Text("auth.invite.footer")
            .frText(FRType.rowSubtitle)
            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            .multilineTextAlignment(.center)
    }
}
