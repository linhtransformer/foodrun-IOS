import SwiftUI

// 5–6 row × 7 column month grid used inside FRWeekCarousel's fold-out.
// Each cell: date number + up to N 5pt truck dots.
// Bundle §"Month fold-out".

public struct FRMonthGrid: View {
    public let month: Date
    public let selectedDate: Date
    public let today: Date
    public let dotsFor: (Date) -> [Color]
    public let onSelect: (Date) -> Void

    private let cal = Calendar(identifier: .gregorian)

    public var body: some View {
        VStack(spacing: 8) {
            // Day-initial headers.
            HStack(spacing: 6) {
                ForEach(weekdayInitials(), id: \.self) { d in
                    Text(d)
                        .frText(FRType.tab)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            // 6 rows × 7 cols grid.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(days(), id: \.self) { day in
                    cell(day)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ day: Date) -> some View {
        let outOfMonth = !cal.isDate(day, equalTo: month, toGranularity: .month)
        let isToday = cal.isDate(day, inSameDayAs: today)
        let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
        let dots = dotsFor(day)
        Button {
            onSelect(day)
            FRHaptic.light.fire()
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 14, weight: dots.isEmpty ? .regular : .bold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Color.foodrun.backgroundInverseInk :
                                     (outOfMonth ? Color.foodrun.foreground.opacity(0.32) : Color.foodrun.foreground))
                HStack(spacing: 2) {
                    ForEach(dots.prefix(4).indices, id: \.self) { i in
                        Circle().fill(dots[i]).frame(width: 5, height: 5)
                    }
                }.frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: FRRadius.inner10.value, style: .continuous)
                    .fill(isToday ? Color.foodrun.foreground :
                          (isSelected ? Color.foodrun.neuTrack : Color.foodrun.card))
            )
            .frNeu(isSelected && !isToday ? .pressed : .raised)
            .opacity(outOfMonth ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.formatted(date: .long, time: .omitted)))
    }

    private func days() -> [Date] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        let firstWeekday = cal.component(.weekday, from: first)   // 1=Sun
        let leading = (firstWeekday + 5) % 7                       // convert to Mon=0
        let start = cal.date(byAdding: .day, value: -leading, to: first)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func weekdayInitials() -> [String] {
        // Locale-aware, starting Monday. NL: M D W D V Z Z / EN: M T W T F S S.
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        return f.veryShortStandaloneWeekdaySymbols.enumerated()
            .sorted { ($0.offset + 6) % 7 < ($1.offset + 6) % 7 }
            .map(\.element)
    }
}

#Preview("Month grid") {
    let today = Fixtures.today
    return FRMonthGrid(
        month: today,
        selectedDate: today,
        today: today,
        dotsFor: { day in
            let n = Calendar.current.component(.day, from: day) % 5
            return n == 0 ? [] : Array(repeating: Color.foodrun.truck.mees, count: min(n, 3))
        },
        onSelect: { _ in }
    )
    .padding(20)
    .background(Color.foodrun.card)
}
