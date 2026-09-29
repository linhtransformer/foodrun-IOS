import SwiftUI

// Bundle §2b "Roster mode".
// 36pt avatar, name (+ "YOU" cap on own row), role · truck, trailing dot + time.

public struct FRRosterRow: View {
    public let name: String
    public let initials: String
    public let avatarColor: Color
    public let role: String
    public let truckName: String
    public let truckColor: Color
    public let time: String
    public let isYou: Bool

    public var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 36, height: 36)
                .background(Circle().fill(avatarColor))
                .frNeu(.raised)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .frText(FRType.rowTitle)
                    if isYou {
                        Text("row.you")
                            .frText(FRType.eyebrow)
                            .foregroundStyle(Color.foodrun.backgroundInverseInk)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.foodrun.foreground))
                    }
                }
                Text("\(role) · \(truckName)")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(truckColor).frame(width: 8, height: 8)
                Text(time)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(isYou ? truckColor.opacity(0.18) : Color.foodrun.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .stroke(isYou ? Color.foodrun.foreground : .clear, lineWidth: 1.5)
        )
        .frNeu(.raised)
    }
}

#Preview("Roster") {
    VStack(spacing: 8) {
        FRRosterRow(name: "Sanne V.", initials: "SV", avatarColor: Color.foodrun.truck.mees,
                    role: "Kitchen", truckName: "Truck Mees", truckColor: Color.foodrun.truck.mees,
                    time: "19:00", isYou: true)
        FRRosterRow(name: "Bram T.", initials: "BT", avatarColor: Color.foodrun.truck.mike,
                    role: "Sales", truckName: "Truck Mees", truckColor: Color.foodrun.truck.mees,
                    time: "19:00", isYou: false)
    }
    .padding(20).background(Color.foodrun.background)
}
