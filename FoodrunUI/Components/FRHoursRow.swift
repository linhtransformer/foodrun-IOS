import SwiftUI

// Bundle §5 "Month log" and §6 approved rows.
// truck dot · day label · venue · hours · state word.

public struct FRHoursRow: View {
    public let truckColor: Color
    public let dayLabel: String        // "Mon 14 Sep"
    public let venue: String
    public let hours: Double           // 6.3 → "6,3 h"
    public let status: HoursStatus

    public var body: some View {
        HStack(spacing: 12) {
            Circle().fill(truckColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel)
                    .frText(FRType.rowTitle)
                Text(venue)
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatHours())
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }

    private var statusLabel: LocalizedStringKey {
        switch status {
        case .pending:  return "hours.status.pending"
        case .approved: return "hours.status.approved"
        case .rejected: return "hours.status.rejected"
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending:  return Color.foodrun.subject.warning
        case .approved: return Color.foodrun.subject.positive
        case .rejected: return Color.foodrun.subject.destructive
        }
    }

    private func formatHours() -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return "\(f.string(from: hours as NSNumber) ?? "0,0") h"
    }
}

#Preview("Hours rows") {
    VStack(spacing: 8) {
        FRHoursRow(truckColor: Color.foodrun.truck.mees,
                   dayLabel: "Mon 14 Sep", venue: "Paradigm · Steenwijk",
                   hours: 6.3, status: .pending)
        FRHoursRow(truckColor: Color.foodrun.truck.mike,
                   dayLabel: "Sat 12 Sep", venue: "Zwarte Cross",
                   hours: 8.5, status: .approved)
    }
    .padding(20).background(Color.foodrun.background)
}
