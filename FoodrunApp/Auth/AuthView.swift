import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                VStack(spacing: FRSpacing.md.value) {
                    // Logo block — F on black rounded square.
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
                    .padding(.top, FRSpacing.xxl.value * 1.5)

                    Text("Foodrun")
                        .font(.system(.title, design: .default).weight(.semibold))
                        .foregroundStyle(Color.foodrun.foreground)
                        .tracking(-0.3)

                    Text("Log in met je e-mailadres.\nWe sturen je een magische link.")
                        .font(Font.foodrun.body)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, FRSpacing.xxl.value)

                // Form
                switch auth.sendStatus {
                case .sent:
                    checkYourEmailBlock
                default:
                    formBlock
                }

                Spacer(minLength: FRSpacing.xxl.value)
            }
            .padding(.horizontal, FRSpacing.lg.value)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var formBlock: some View {
        VStack(spacing: FRSpacing.md.value) {
            FRTextField(
                "E-mail",
                text: $email,
                placeholder: "jij@voorbeeld.nl",
                keyboard: .emailAddress,
                contentType: .emailAddress
            )

            if case .failed(let msg) = auth.sendStatus {
                Text(msg)
                    .font(Font.foodrun.caption)
                    .foregroundStyle(Color.foodrun.subject.cost)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            FRPrimaryButton(
                sendButtonTitle,
                isLoading: auth.sendStatus == .sending,
                isDisabled: email.isEmpty
            ) {
                Task { await auth.sendMagicLink(email: email) }
            }

            Text("Nog geen account? De link maakt er een voor je aan.")
                .font(Font.foodrun.caption)
                .foregroundStyle(Color.foodrun.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.top, FRSpacing.sm.value)
        }
    }

    private var sendButtonTitle: String {
        switch auth.sendStatus {
        case .sending: return "Bezig…"
        default:       return "Stuur magische link"
        }
    }

    private var checkYourEmailBlock: some View {
        VStack(spacing: FRSpacing.lg.value) {
            ZStack {
                Circle().fill(Color.foodrun.subject.revenue.opacity(0.14)).frame(width: 72, height: 72)
                Image(systemName: "envelope.badge")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.foodrun.subject.revenue)
            }

            VStack(spacing: FRSpacing.xs.value) {
                Text("Check je inbox")
                    .font(Font.foodrun.sectionTitle)
                    .foregroundStyle(Color.foodrun.foreground)
                Text("We hebben een link gestuurd naar\n\(email). Open die op deze telefoon om in te loggen.")
                    .font(Font.foodrun.body)
                    .foregroundStyle(Color.foodrun.mutedForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FRSecondaryButton("Ander adres proberen") {
                auth.reset()
                email = ""
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
