import SwiftUI

// Two densities per bundle §2a "Shifts mode":
//  * .full — selected-day rows with tint fill + 4pt truck-colored left border.
//  * .compact — still-to-work rows in a dense list (9×12pt padding, 14pt radius).

public struct FRShiftRow: View {
    public enum Density { case full, compact }

    public let density: Density
    public let time: String            // "19:00 – 23:00"
    public let truckName: String       // "Truck Mees"
    public let truckColor: Color
    public let venue: String
    public let role: String
    public let status: String          // "CONFIRMED", "WAITING", …
    public let statusColor: Color
    public let date: Date              // used for the compact left block
    public let isToday: Bool           // yellow tint marks today's shift inside "Still to work"
    public var onTap: (() -> Void)?

    public init(density: Density, time: String, truckName: String, truckColor: Color,
                venue: String, role: String, status: String, statusColor: Color,
                date: Date, isToday: Bool = false, onTap: (() -> Void)? = nil) {
        self.density = density; self.time = time
        self.truckName = truckName; self.truckColor = truckColor
        self.venue = venue; self.role = role
        self.status = status; self.statusColor = statusColor
        self.date = date; self.isToday = isToday
        self.onTap = onTap
    }

    public var body: some View {
        switch density {
        case .full:    fullRow
        case .compact: compactRow
        }
    }

    private var fullRow: some View {
        Button { onTap?() } label: {
            HStack(alignment: .top) {
                Rectangle()
                    .fill(truckColor)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(time)
                            .frText(FRType.rowTitle)
                            .monospacedDigit()
                        Text(truckName)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    Text(venue)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.foodrun.foreground)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status)
                        .frText(FRType.fieldLabel)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(statusColor.opacity(0.15)))
                        .foregroundStyle(statusColor)
                    Text(role)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                    .fill(truckColor.opacity(0.18))
            )
            .frNeu(.raised)
        }
        .buttonStyle(.plain)
    }

    private var compactRow: some View {
        Button { onTap?() } label: {
            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text(dateDayLabel())
                        .frText(FRType.tab)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    Text(dateDayNumber())
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.foodrun.foreground)
                }
                .frame(width: 32)
                Rectangle()
                    .fill(truckColor)
                    .frame(width: 3, height: 30)
                    .clipShape(Capsule())
                VStack(alignment: .leading, spacing: 2) {
                    Text(time)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    Text(venue)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(status)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(statusColor)
                    Text(role)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: FRRadius.listRowSm.value, style: .continuous)
                    .fill(isToday ? Color.foodrun.truck.mees.opacity(0.35) : Color.foodrun.card)
            )
            .frNeu(.raised)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Format

    private func dateDayLabel() -> String {
        let f = DateFormatter(); f.locale = FRLanguage.locale; f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
    private func dateDayNumber() -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }
}

#Preview("Shift rows") {
    VStack(spacing: 12) {
        FRShiftRow(
            density: .full, time: "19:00 – 23:00",
            truckName: "Truck Mees", truckColor: Color.foodrun.truck.mees,
            venue: "Paradigm · Steenwijk", role: "Kitchen",
            status: "CONFIRMED", statusColor: Color.foodrun.subject.positive,
            date: Fixtures.today
        )
        FRShiftRow(
            density: .compact, time: "12:00 – 22:00",
            truckName: "Truck Mike", truckColor: Color.foodrun.truck.mike,
            venue: "Zwarte Cross · Lichtenvoorde", role: "Kitchen",
            status: "CONFIRMED", statusColor: Color.foodrun.subject.positive,
            date: Fixtures.today
        )
    }
    .padding(20)
    .background(Color.foodrun.background)
}
