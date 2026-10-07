import SwiftUI

// Bundle §8. Profile. Everything here is real: name/email from the linked
// employee row + auth session, stats from the loaded schedule and hours, and
// every row does something (App Review rejects dead buttons). Account
// deletion lives here per guideline 5.1.1(v).

public struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(ScheduleStore.self) private var schedule
    @Environment(HoursStore.self) private var hours

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatar
                if !schedule.employees.isEmpty { stats }
                ProfileAccountSection()
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
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
                .background(Circle().fill(Color.foodrun.truck.mees))
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
    @State private var showJoin = false
    @State private var confirmLogout = false
    @State private var confirmDelete = false
    @State private var deleteFailed = false
    @State private var showLanguage = false
    @State private var pendingLanguage: FRLanguage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.section.account").frText(FRType.sectionHeader)
            VStack(spacing: 6) {
                if showsJoinRow {
                    // Workers can work for several organizations (one employee row each).
                    Button { showJoin = true } label: {
                        row("building.2", "profile.joinAnother", trailing: "chevron.right")
                    }
                }
                Button { showLanguage = true } label: {
                    row("globe", "profile.language", value: FRLanguage.current.displayName, trailing: "chevron.right")
                }
                Link(destination: AppConfig.privacyURL) {
                    row("hand.raised", "legal.privacy", trailing: "arrow.up.right")
                }
                Link(destination: AppConfig.supportURL) {
                    row("questionmark.circle", "profile.help", trailing: "envelope")
                }
                Button { confirmLogout = true } label: {
                    row("rectangle.portrait.and.arrow.right", "profile.logout", trailing: nil)
                }
                Button { confirmDelete = true } label: {
                    row("trash", "profile.deleteAccount", trailing: nil, destructive: true)
                }
            }
            .buttonStyle(.plain)
            Text("profile.version")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
        .sheet(isPresented: $showJoin) {
            JoinRequestView { await schedule.load() }
        }
        .sheet(isPresented: $showLanguage, onDismiss: applyLanguage) {
            languageSheet
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("profile.logout.confirm", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("profile.logout", role: .destructive) {
                FRHaptic.warning.fire()
                Task { await auth.signOut() }
            }
        }
        .confirmationDialog("profile.deleteAccount.title", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("profile.deleteAccount.confirm", role: .destructive) {
                Task {
                    if await auth.deleteAccount() {
                        FRHaptic.success.fire()
                    } else {
                        FRHaptic.error.fire()
                        deleteFailed = true
                    }
                }
            }
        } message: {
            Text("profile.deleteAccount.body")
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
