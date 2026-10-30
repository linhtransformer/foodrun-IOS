import MessageUI
import SwiftUI
import UIKit

// Bundle §8. Profile. Everything here is real: name/email from the linked
// employee row + auth session, stats from the loaded schedule and hours, and
// every row does something (App Review rejects dead buttons). Account
// deletion lives here per guideline 5.1.1(v).

public struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(ScheduleStore.self) private var schedule
    @Environment(HoursStore.self) private var hours
    @Environment(SwapStore.self) private var swaps
    @Environment(TabRouter.self) private var router

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatar
                // Right under the name so an employer finds the switch without scrolling.
                if !schedule.employees.isEmpty { stats }
                if !schedule.employees.isEmpty { workSection }
                if !organizations.isEmpty { organizationsSection }
                ProfileAccountSection(onOpenSettings: { router.mePath.append(.settings) })
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    /// Ruilen and Verlof — the worker's own requests.
    private var workSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.section.work").frText(FRType.sectionHeader)
            VStack(spacing: 6) {
                if AppConfig.Features.shiftSwaps {
                    Button { router.mePath.append(.swaps) } label: {
                        navRow("arrow.left.arrow.right", "profile.swaps", badge: swaps.attentionCount)
                    }
                }
                Button { router.mePath.append(.leave) } label: {
                    navRow("calendar.badge.minus", "profile.leave", badge: 0)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func navRow(_ symbol: String, _ label: LocalizedStringKey, badge: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
            Text(label).frText(FRType.rowTitle)
            Spacer()
            if badge > 0 {
                Text(verbatim: "\(badge)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.foodrun.subject.warning))
            }
            Image(systemName: "chevron.right").foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
        .foregroundStyle(Color.foodrun.foreground)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
        .frNeu(.raised)
        .contentShape(Rectangle())
    }

    /// Who this account works for (or is waiting on) — so it's never a guess
    /// which employer a login is tied to.
    /// Employers this account works for or is waiting on (not declined), then
    /// the ones it has left ("uit dienst"), marked as such.
    private var organizations: [MyOrganization] {
        schedule.organizations.filter(\.isCurrent) + schedule.organizations.filter(\.isFormer)
    }

    private var organizationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.section.organizations").frText(FRType.sectionHeader)
            VStack(spacing: 6) {
                ForEach(organizations) { org in
                    HStack(spacing: 12) {
                        Image(systemName: "building.2").font(.system(size: 15, weight: .medium))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: org.name).frText(FRType.rowTitle)
                            // Left: a muted line instead of looking like a current employer.
                            if org.isFormer, let leftOn = org.left_on {
                                Text("profile.org.leftOn \(SchemaDates.display(leftOn))")
                                    .frText(FRType.rowSubtitle)
                                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                            }
                        }
                        Spacer(minLength: 8)
                        if org.approval_status == "pending" {
                            Text("profile.org.pending")
                                .frText(FRType.rowSubtitle)
                                .foregroundStyle(Color.foodrun.subject.warning)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                    .frNeu(.raised)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var email: String {
        if case .signedIn(let email) = auth.state { return email }
        return ""
    }

    private var displayName: String {
        let name = schedule.employees.first?.fullName ?? ""
        return name.isEmpty ? email : name
    }

    private var avatar: some View {
        VStack(spacing: 8) {
            Text(verbatim: initials())
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.foodrunData(hex: schedule.employees.first?.color)))
                .frNeu(.raisedLg)
            Text(verbatim: displayName)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            if displayName != email {
                Text(verbatim: email).frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    private var stats: some View {
        let monthShifts = schedule.shifts.filter {
            Calendar.current.isDate($0.date, equalTo: schedule.today, toGranularity: .month)
        }.count
        let approved = hours.rows.filter { $0.status == .approved }.map(\.hours).reduce(0, +)
        return HStack(spacing: 10) {
            statCard("\(monthShifts)", "profile.stat.shiftsMonth")
            statCard("\(schedule.upcomingShifts.count)", "profile.stat.upcoming")
            statCard(String(format: "%.0f", approved), "profile.stat.hoursApproved")
        }
    }

    private func statCard(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: value).font(.system(size: 20, weight: .heavy).monospacedDigit())
            Text(label).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: FRRadius.container.value).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private func initials() -> String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

/// Language, privacy, help, log out, delete account. Shared by Profile and the
/// "waiting for your employer" screen, which has no tabs.
struct ProfileAccountSection: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(ScheduleStore.self) private var schedule
    /// The waiting screen has its own big "ask an organization" button.
    var showsJoinRow = true
    /// Ik: opens Instellingen (language, appearance, notifications, delete account). The
    /// waiting screen has no settings page, so it keeps language and delete here.
    var onOpenSettings: (() -> Void)? = nil
    @State private var showJoin = false
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var deleteFailed = false
    @State private var showLanguage = false
    @State private var pendingLanguage: FRLanguage?
    @State private var opening: CrewOpenedURL?
    @State private var showHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.section.account").frText(FRType.sectionHeader)
            VStack(spacing: 6) {
                if showsJoinRow && AppConfig.Features.joinByCode {
                    // Workers can work for several organizations (one employee row each).
                    Button { showJoin = true } label: {
                        row("building.2", "profile.joinAnother", trailing: "chevron.right")
                    }
                }
                if let onOpenSettings {
                    Button(action: onOpenSettings) {
                        row("gearshape", "settings.title", trailing: "chevron.right")
                    }
                } else {
                    Button { showLanguage = true } label: {
                        row("globe", "profile.language", value: FRLanguage.current.displayName, trailing: "chevron.right")
                    }
                }
                // Both open inside the app: privacy in an in-app Safari sheet,
                // help as a sheet with an in-app mail composer.
                Button { opening = CrewOpenedURL(url: AppConfig.privacyURL) } label: {
                    row("hand.raised", "legal.privacy", trailing: "chevron.right")
                }
                Button { showHelp = true } label: {
                    row("questionmark.circle", "profile.help", trailing: "chevron.right")
                }
                // Each confirmation hangs on its own button: on iOS 26 the dialog points at the view
                // it is attached to, and on the whole section it popped up by the "Account" heading.
                Button { confirmLogout = true } label: {
                    row("rectangle.portrait.and.arrow.right", "profile.logout", trailing: nil)
                }
                .confirmationDialog("profile.logout.confirm", isPresented: $confirmLogout, titleVisibility: .visible) {
                    Button("profile.logout", role: .destructive) {
                        FRHaptic.warning.fire()
                        Task { await auth.signOut() }
                    }
                }
            }
            .buttonStyle(.plain)
            // The real version and build ("Foodrun 1.0 (9)"), so it's clear which build a phone runs.
            Text(verbatim: "Foodrun \(FoodrunVersion.text)")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            // Far from "Uitloggen" on purpose, and only a small link: deleting opens its own page
            // where the word VERWIJDEREN has to be typed (one mis-tap removed a test account).
            // On Ik this lives in Instellingen.
            if onOpenSettings == nil {
                Button { confirmDelete = true } label: {
                    Text("profile.deleteAccount")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
        }
        .sheet(isPresented: $confirmDelete) {
            DeleteAccountSheet {
                if await auth.deleteAccount() {
                    FRHaptic.success.fire()
                    return true
                }
                FRHaptic.error.fire()
                deleteFailed = true
                return false
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinRequestView { await schedule.load() }
        }
        .sheet(item: $opening) { CrewSafariView(url: $0.url).ignoresSafeArea() }
        .sheet(isPresented: $showHelp) {
            HelpSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLanguage, onDismiss: applyLanguage) {
            languageSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .alert("profile.deleteAccount.failed", isPresented: $deleteFailed) {
            Button("action.ok", role: .cancel) {}
        } message: {
            if case .failed(let message) = auth.status { Text(verbatim: message) }
        }
    }

    private func row(_ symbol: String, _ label: LocalizedStringKey, value: String? = nil,
                     trailing: String?, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
            Text(label).frText(FRType.rowTitle)
            Spacer()
            if let value {
                Text(verbatim: value)
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            if let trailing {
                Image(systemName: trailing)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
        .foregroundStyle(destructive ? Color.foodrun.subject.destructive : Color.foodrun.foreground)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
        .frNeu(.raised)
        .contentShape(Rectangle())
    }

    private var languageSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("profile.language.title").frText(FRType.sectionHeader)
            VStack(spacing: 6) {
                ForEach(FRLanguage.allCases) { option in
                    Button {
                        pendingLanguage = option
                        showLanguage = false
                        FRHaptic.light.fire()
                    } label: {
                        HStack {
                            Text(verbatim: option.displayName).frText(FRType.rowTitle)
                            Spacer()
                            if option == FRLanguage.current {
                                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                        .frNeu(.raised)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.foodrun.background)
    }

    /// Applied after the sheet closes: the switch rebuilds the shell (see RootView).
    private func applyLanguage() {
        if let pendingLanguage, pendingLanguage != FRLanguage.current {
            FRLanguage.set(pendingLanguage)
        }
        pendingLanguage = nil
    }
}

/// Me → Hulp & contact. Stays in the app: who to ask about what, and a mail to
/// support written in Apple's in-app composer. A phone without a mail account
/// gets the address copied instead.
struct HelpSheet: View {
    @State private var composing = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("profile.help").frText(FRType.sectionHeader)
            Text("help.body")
                .frText(FRType.body)
                .foregroundStyle(Color.foodrun.foreground)
                .fixedSize(horizontal: false, vertical: true)
            FRPrimaryButton(FRLanguage.string("help.mail")) {
                if MFMailComposeViewController.canSendMail() {
                    composing = true
                } else {
                    UIPasteboard.general.string = AppConfig.supportEmail
                    copied = true
                    FRHaptic.success.fire()
                }
            }
            Text(verbatim: AppConfig.supportEmail)
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity)
            if copied {
                Text("help.copied")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.subject.positive)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.foodrun.background)
        .sheet(isPresented: $composing) {
            SupportMailComposer(
                recipient: AppConfig.supportEmail,
                subject: FRLanguage.string("help.mail.subject"),
                body: "\n\n—\nFoodrun iOS \(Self.appVersion)",
                onFinish: { composing = false }
            )
            .ignoresSafeArea()
        }
    }

    private static var appVersion: String { FoodrunVersion.text }
}

/// Apple's mail composer, inside the app.
struct SupportMailComposer: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients([recipient])
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish()
        }
    }
}

/// "1.0 (9)": the version and build number, for the Me footer and support mails.
enum FoodrunVersion {
    static var text: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

/// Deleting an account: what it removes, and the word VERWIJDEREN / DELETE to type before the
/// red button works. Cancel is the big, easy choice.
struct DeleteAccountSheet: View {
    let onDelete: () async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @State private var working = false

    private var word: String { FRLanguage.string("profile.deleteAccount.word") }
    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespaces).uppercased() == word.uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CrewSheetHeader(title: FRLanguage.string("profile.deleteAccount.title")) { dismiss() }
            Text("profile.deleteAccount.body")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text(verbatim: String(format: FRLanguage.string("profile.deleteAccount.typeWord %@"), word))
                .frText(FRType.rowTitle)
            TextField(text: $typed, prompt: Text(verbatim: word)) { Text(verbatim: word) }
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
            AuthPrimaryButton(title: "action.cancel", working: false) { dismiss() }
            Button {
                Task {
                    working = true
                    if await onDelete() { dismiss() }
                    working = false
                }
            } label: {
                ZStack {
                    if working { ProgressView() } else { Text("profile.deleteAccount.confirm") }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.subject.destructive)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(Capsule().stroke(Color.foodrun.subject.destructive, lineWidth: 1))
                .opacity(matches ? 1 : 0.35)
            }
            .buttonStyle(.plain)
            .disabled(!matches || working)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled(working)
    }
}
