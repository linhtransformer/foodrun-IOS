import SwiftUI

// Bundle §2 "Week carousel".
// Header: 28pt ‹ button, center week label + range/count, calendar toggle, 28pt ›.
// Below: 7 day columns — 2-letter label, 34pt date cell, 16×3pt truck bar.

public struct FRWeekCarousel: View {
    @Binding public var selectedDate: Date
    @Binding public var weekOffset: Int
    @Binding public var monthOpen: Bool
    public let today: Date
    public let barColorFor: (Date) -> Color?         // truck color (or nil)
    public let shiftCount: (Date) -> Int             // # shifts on the day (for month grid)

    private let cal = Calendar(identifier: .gregorian)

    public var body: some View {
        VStack(spacing: 12) {
            header
            weekRow
            if monthOpen {
                Divider().overlay(Color.foodrun.border)
                FRMonthGrid(
                    month: currentWeekStart,
                    selectedDate: selectedDate,
                    today: today,
                    dotsFor: { d in
                        let c = shiftCount(d)
                        return c == 0 ? [] : Array(repeating: barColorFor(d) ?? Color.foodrun.truck.mees, count: min(c, 3))
                    },
                    onSelect: { selectedDate = $0 }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            stepButton(direction: -1, symbol: "chevron.left")
            VStack(spacing: 2) {
                Text("Week \(weekNumber)")
                    .frText(FRType.segmented)
                    .foregroundStyle(Color.foodrun.foreground)
                Text(rangeSubtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }.frame(maxWidth: .infinity)
            Button {
                withAnimation(FRAnimation.monthStep) { monthOpen.toggle() }
                FRHaptic.light.fire()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(monthOpen ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(monthOpen ? Color.foodrun.foreground : Color.foodrun.neuPill)
                    )
            }
            .buttonStyle(.plain)
            .frNeu(monthOpen ? .pressed : .raised)
            .accessibilityLabel(Text("action.toggleMonth"))
            stepButton(direction: +1, symbol: "chevron.right")
        }
    }

    private func stepButton(direction: Int, symbol: String) -> some View {
        Button {
            withAnimation(FRAnimation.weekStep) {
                weekOffset += direction
                selectedDate = cal.date(byAdding: .weekOfYear, value: direction, to: selectedDate) ?? selectedDate
            }
            FRHaptic.light.fire()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.foodrun.neuPill))
        }
        .buttonStyle(.plain)
        .frNeu(.raised)
    }

    // MARK: - Week row

    private var weekRow: some View {
        HStack(spacing: 4) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let selected = cal.isDate(day, inSameDayAs: selectedDate)
        let isToday = cal.isDate(day, inSameDayAs: today)
        let bar = barColorFor(day)
        return Button {
            withAnimation(FRAnimation.dayFade) { selectedDate = day }
            FRHaptic.light.fire()
        } label: {
            VStack(spacing: 4) {
                Text(twoLetterDay(day))
                    .frText(FRType.tab)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: FRRadius.dayCell.value, style: .continuous)
                            .fill(isToday ? Color.foodrun.foreground :
                                  (selected ? Color.foodrun.neuTrack : Color.foodrun.card))
                    )
                    .shadow(color: .black.opacity(isToday ? 0.2 : 0), radius: isToday ? 5 : 0, y: isToday ? 2 : 0)
                Rectangle()
                    .fill(bar ?? .clear)
                    .frame(width: 16, height: 3)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.formatted(date: .long, time: .omitted)))
    }

    // MARK: - Derived

    private var currentWeekStart: Date {
        let baseline = cal.date(byAdding: .weekOfYear, value: weekOffset, to: today) ?? today
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseline)
        comps.weekday = 2  // Monday
        return cal.date(from: comps) ?? baseline
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: currentWeekStart) }
    }

    private var weekNumber: Int {
        cal.component(.weekOfYear, from: currentWeekStart)
    }

    private var rangeSubtitle: String {
        let end = cal.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
        let f = DateFormatter(); f.dateFormat = "d"
        let g = DateFormatter(); g.dateFormat = "d MMM"
        return "\(f.string(from: currentWeekStart)) – \(g.string(from: end))"
    }

    private func twoLetterDay(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        let raw = f.shortStandaloneWeekdaySymbols[cal.component(.weekday, from: day) - 1]
        return String(raw.prefix(2))
    }
}

#Preview("Week carousel") {
    struct H: View {
        @State var selected: Date = Fixtures.today
        @State var offset: Int = 0
        @State var month: Bool = false
        var body: some View {
            FRWeekCarousel(
                selectedDate: $selected,
                weekOffset: $offset,
                monthOpen: $month,
                today: Fixtures.today,
                barColorFor: { d in
                    let dow = Calendar.current.component(.weekday, from: d)
                    return dow == 4 ? Color.foodrun.truck.mees : nil
                },
                shiftCount: { d in
                    Calendar.current.component(.weekday, from: d) == 4 ? 1 : 0
                }
            )
            .padding(20)
            .background(Color.foodrun.background)
        }
    }
    return H()
}
