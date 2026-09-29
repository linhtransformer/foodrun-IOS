import SwiftUI

// Bundle §8. Profile.

public struct ProfileView: View {
    @Environment(ScheduleStore.self) private var schedule

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatar
                stats
                account
                logout
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var avatar: some View {
        VStack(spacing: 8) {
            Text(initials())
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 76, height: 76)
                .background(Circle().fill(Color.foodrun.truck.mees))
                .frNeu(.raisedLg)
            Text(schedule.employees.first?.name ?? "Sanne V.")
                .font(.system(size: 22, weight: .bold))
            Text("profile.role.line").frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private var stats: some View {
        HStack(spacing: 10) {
            statCard("14", "profile.stat.shifts")
            statCard("92%", "profile.stat.checklists")
            statCard("3", "profile.stat.trucks")
        }
    }
    private func statCard(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 20, weight: .heavy).monospacedDigit())
            Text(label).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: FRRadius.container.value).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private var account: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.section.account").frText(FRType.sectionHeader)
            VStack(spacing: 6) {
                row("globe", "profile.language")
                row("bell", "profile.notifications")
                row("doc.text", "profile.payslips")
                row("building.2", "profile.contract")
                row("questionmark.circle", "profile.help")
            }
        }
    }

    private func row(_ symbol: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .medium))
            Text(label).frText(FRType.rowTitle)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private var logout: some View {
        VStack(spacing: 6) {
            Button { FRHaptic.warning.fire() } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("profile.logout")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.subject.destructive)
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(Capsule().stroke(Color.foodrun.subject.destructive, lineWidth: 1))
            }.buttonStyle(.plain)
            Text("profile.version")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private func initials() -> String {
        let name = schedule.employees.first?.name ?? "Sanne V."
        return name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
    }
}
