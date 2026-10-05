import SwiftUI

// Bundle §6. Approved hours ledger — every employee_hours row the operator
// approved in HQ, newest month first.

public struct ApprovedHoursView: View {
    @Environment(HoursStore.self) private var hours
    @Environment(ScheduleStore.self) private var schedule
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private var approved: [DBEmployeeHours] {
        hours.rows.filter { $0.status == .approved }.sorted { $0.work_date > $1.work_date }
    }

    /// "yyyy-MM" → rows, so months sort chronologically (not alphabetically).
    private var groups: [(key: String, rows: [DBEmployeeHours])] {
        Dictionary(grouping: approved) { String($0.work_date.prefix(7)) }
            .map { (key: $0.key, rows: $0.value) }
            .sorted { $0.key > $1.key }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCard
                monthGroups
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.foodrun.card))
                    .frNeu(.raised)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.back"))
            Spacer()
        }
    }

    private var summaryCard: some View {
        let total = approved.map(\.hours).reduce(0, +)
        return VStack(alignment: .leading, spacing: 6) {
            Text("approved.eyebrow").frText(FRType.eyebrow)
                .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.6))
            HStack(alignment: .lastTextBaseline) {
                Text(format(total))
                    .font(.system(size: 40, weight: .heavy).monospacedDigit()).tracking(-1.2)
                Text("approved.totalShifts \(approved.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.7))
            }
        }
        .foregroundStyle(Color.foodrun.backgroundInverseInk)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous)
                .fill(Color.foodrun.foreground)
        )
    }

    private var monthGroups: some View {
        VStack(alignment: .leading, spacing: 16) {
            if approved.isEmpty {
                Text("approved.empty")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            ForEach(groups, id: \.key) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(monthLabel(group.key)).frText(FRType.sectionHeader)
                        Spacer()
                        Rectangle().fill(Color.foodrun.border).frame(height: 1)
                        Text(verbatim: FRLanguage.hours(group.rows.map(\.hours).reduce(0, +)))
                            .frText(FRType.rowTitle)
                    }
                    ForEach(group.rows) { row in
                        let activity = schedule.activities.first { $0.id == row.activity_id }
                        FRHoursRow(
                            truckColor: Color.foodrunData(hex: activity?.color),
                            dayLabel: dayLabel(row.workDay),
                            venue: activity?.name ?? "—",
                            hours: row.hours,
                            status: row.status
                        )
                    }
                }
            }
        }
    }

    private func format(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = FRLanguage.locale
        f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
        return f.string(from: v as NSNumber) ?? "0,0"
    }

    private func monthLabel(_ yyyyMM: String) -> String {
        guard let d = SchemaDates.date("\(yyyyMM)-01") else { return yyyyMM }
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = FRLanguage.locale
        return f.string(from: d)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: date)
    }
}
