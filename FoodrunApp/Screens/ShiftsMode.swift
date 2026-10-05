import SwiftUI

// Bundle §2a. One unified "Still to work" list: every rostered shift from today
// on. Today's shift sits first with a yellow tint. Status reflects the hours the
// worker already submitted for that day (employee_hours).

struct ShiftsMode: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(HoursStore.self) private var hours
    @Environment(TabRouter.self) private var router
    @Environment(ShiftChangeStore.self) private var changes

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("shifts.stillToWork.title").frText(FRType.sectionHeader)
                Spacer()
                Text(totals)
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            if schedule.upcomingShifts.isEmpty {
                Text(LocalizedStringKey(schedule.isLoading ? "shifts.loading" : "shifts.none"))
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                            .strokeBorder(Color.foodrun.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }
            VStack(spacing: 6) {
                ForEach(schedule.upcomingShifts) { shift in
                    let status = statusFor(shift)
                    FRShiftRow(
                        density: .compact,
                        time: shift.timeLabel,
                        truckName: shift.activity.food_truck ?? shift.activity.name,
                        truckColor: Color.foodrunData(hex: shift.activity.color),
                        venue: shift.activity.location ?? shift.activity.name,
                        role: shift.employee.roles?.first ?? "",
                        status: status.label,
                        statusColor: status.color,
                        date: shift.date,
                        isToday: schedule.isToday(shift.date),
                        onTap: {
                            router.pushOnShifts(.shiftDetail(activityId: shift.activity.id, date: shift.date))
                        }
                    )
                }
            }
        }
    }

    private var totals: String {
        let list = schedule.upcomingShifts
        let h = list.reduce(0) { $0 + $1.plannedHours }
        return "\(FRLanguage.string("shifts.count %lld", list.count)) · \(FRLanguage.hours(h))"
    }

    private func statusFor(_ shift: WorkerShift) -> (label: String, color: Color) {
        switch hours.row(activityId: shift.activity.id, day: shift.day)?.status {
        case .approved?: return (statusLabel("shift.status.approved"), Color.foodrun.subject.positive)
        case .pending?:  return (statusLabel("shift.status.submitted"), Color.foodrun.subject.warning)
        case .rejected?: return (statusLabel("shift.status.rejected"), Color.foodrun.subject.destructive)
        case nil where changes.isChanged(shift):
                         return (statusLabel("shift.status.changed"), Color.foodrun.subject.warning)
        case nil:        return (statusLabel("shift.status.scheduled"), Color.foodrun.subject.positive)
        }
    }

    private func statusLabel(_ key: String) -> String {
        FRLanguage.string(key).uppercased(with: FRLanguage.locale)
    }
}
