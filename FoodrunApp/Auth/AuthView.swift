import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                VStack(spacing: FRSpacing.md.value) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.foodrun.foreground)
                            .frame(width: 84, height: 84)
                        Text("F")
                            .font(.system(size: 44, weight: .bold, design: .default))
                            .foregroundStyle(Color.foodrun.surface)
                        Circle()
                            .fill(Color.foodrun.surface)
                            .frame(width: 8, height: 8)
                            .offset(x: 22, y: 22)
                    }
                    .frElevation(.pop)
                    .padding(.top, FRSpacing.xxl.value)

                    Text("Foodrun")
                        .font(.system(.title, design: .default).weight(.semibold))
                        .foregroundStyle(Color.foodrun.foreground)
                        .tracking(-0.3)

                    Text(headerCopy)
                        .font(Font.foodrun.body)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, FRSpacing.md.value)
                }
                .padding(.bottom, FRSpacing.lg.value)

                // Mode picker
                if !isConfirmationScreen {
                    modePicker
                        .padding(.horizontal, FRSpacing.lg.value)
                        .padding(.bottom, FRSpacing.lg.value)
                }

                // Form
                Group {
                    switch auth.status {
                    case .magicLinkSent:
                        confirmationBlock(
                            title: "Check je inbox",
                            message: "We hebben een link gestuurd naar\n\(email). Open die op deze telefoon om in te loggen.",
                            iconName: "envelope.badge"
                        )
                    case .signUpConfirmationSent:
                        confirmationBlock(
                            title: "Bevestig je e-mail",
                            message: "We hebben een bevestigingslink gestuurd naar\n\(email). Klik die aan om je account te activeren.",
                            iconName: "checkmark.seal"
                        )
                    default:
                        formBlock
                    }
                }
                .padding(.horizontal, FRSpacing.lg.value)

                Spacer(minLength: FRSpacing.xxl.value)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var headerCopy: String {
        switch auth.mode {
        case .password:
            return auth.passwordSubmode == .signIn
                ? "Log in met je e-mailadres en wachtwoord."
                : "Maak een account aan met je e-mailadres."
        case .magicLink:
            return "Log in met je e-mailadres.\nWe sturen je een magische link."
        }
    }

    private var isConfirmationScreen: Bool {
        auth.status == .magicLinkSent || auth.status == .signUpConfirmationSent
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(AuthViewModel.Mode.allCases) { m in
                Button {
                    auth.mode = m
                    auth.reset()
                } label: {
                    Text(m.rawValue)
                        .font(Font.foodrun.body.weight(auth.mode == m ? .semibold : .regular))
                        .foregroundStyle(auth.mode == m ? Color.foodrun.surface : Color.foodrun.foreground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(auth.mode == m ? Color.foodrun.foreground : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Color.foodrun.surface)
        )
        .frElevation(.pop)
    }

    // MARK: - Form

    private var formBlock: some View {
        VStack(spacing: FRSpacing.md.value) {
            FRTextField(
                "E-mail",
                text: $email,
                placeholder: "jij@voorbeeld.nl",
                keyboard: .emailAddress,
                contentType: .emailAddress
            )

            if auth.mode == .password {
                FRTextField(
                    "Wachtwoord",
                    text: $password,
                    placeholder: "Minimaal 8 tekens",
                    contentType: auth.passwordSubmode == .signIn ? .password : .newPassword,
                    isSecure: true
                )
            }

            if case .failed(let msg) = auth.status {
                Text(msg)
                    .font(Font.foodrun.caption)
                    .foregroundStyle(Color.foodrun.subject.cost)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FRPrimaryButton(
                primaryButtonTitle,
                isLoading: auth.status == .working,
                isDisabled: primaryDisabled
            ) {
                Task { await submit() }
            }

            if auth.mode == .password {
                subModeSwitcher
            } else {
                Text("Nog geen account? De link maakt er een voor je aan.")
                    .font(Font.foodrun.caption)
                    .foregroundStyle(Color.foodrun.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.top, FRSpacing.sm.value)
            }
        }
    }

    private var subModeSwitcher: some View {
        HStack(spacing: 4) {
            Text(auth.passwordSubmode == .signIn ? "Nog geen account?" : "Al een account?")
                .font(Font.foodrun.caption)
                .foregroundStyle(Color.foodrun.mutedForeground)
            Button {
                auth.passwordSubmode = auth.passwordSubmode == .signIn ? .signUp : .signIn
                auth.reset()
            } label: {
                Text(auth.passwordSubmode == .signIn ? "Registreer" : "Log in")
                    .font(Font.foodrun.caption.weight(.semibold))
                    .foregroundStyle(Color.foodrun.foreground)
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .padding(.top, FRSpacing.sm.value)
    }

    private var primaryButtonTitle: String {
        if auth.status == .working { return "Bezig…" }
        switch auth.mode {
        case .password:
            return auth.passwordSubmode.rawValue
        case .magicLink:
            return "Stuur magische link"
        }
    }

    private var primaryDisabled: Bool {
        if email.isEmpty { return true }
        if auth.mode == .password, password.isEmpty { return true }
        return false
    }

    private func submit() async {
        switch auth.mode {
        case .magicLink:
            await auth.sendMagicLink(email: email)
        case .password:
            switch auth.passwordSubmode {
            case .signIn:
                await auth.signIn(email: email, password: password)
            case .signUp:
                await auth.signUp(email: email, password: password)
            }
        }
    }

    // MARK: - Confirmation

    private func confirmationBlock(title: String, message: String, iconName: String) -> some View {
        VStack(spacing: FRSpacing.lg.value) {
            ZStack {
                Circle().fill(Color.foodrun.subject.revenue.opacity(0.14)).frame(width: 72, height: 72)
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.foodrun.subject.revenue)
            }

            VStack(spacing: FRSpacing.xs.value) {
                Text(title)
                    .font(Font.foodrun.sectionTitle)
                    .foregroundStyle(Color.foodrun.foreground)
                Text(message)
                    .font(Font.foodrun.body)
                    .foregroundStyle(Color.foodrun.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FRSecondaryButton("Ander adres proberen") {
                auth.reset()
                email = ""
                password = ""
            }
        }
        .padding(FRSpacing.lg.value)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.card.value, style: .continuous)
                .fill(Color.foodrun.surface)
        )
        .frElevation(.pop)
    }
}

#Preview {
    AuthView().environmentObject(AuthViewModel())
}
