import SwiftUI

// Bundle §4. Full checklist.

public struct TasksView: View {
    @Environment(TasksStore.self) private var tasks
    @Environment(ScheduleStore.self) private var schedule
    @State private var submittedAt: Date?

    /// The checklist belongs to the worker's current / next shift.
    private var shift: WorkerShift? { schedule.nextShift }

    private var shiftDateLine: String? {
        guard let shift else { return nil }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return "\(f.string(from: shift.date)) · \(shift.timeLabel)"
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                progressCard
                sectionHeader
                VStack(spacing: 10) {
                    ForEach(tasks.items) { item in
                        FRTaskRow(
                            title: item.title,
                            note: item.note,
                            completed: item.completed_at != nil,
                            completedAt: item.completed_at,
                            value: item.value,
                            requiresPhoto: item.requires_photo,
                            onToggle: { tasks.toggle(item.id) },
                            onSetValue: item.requires_value ? { /* value picker */ } : nil,
                            onPickPhoto: item.requires_photo ? { /* photo picker */ } : nil,
                            shift: shift?.activity.name,
                            shiftDate: shiftDateLine
                        )
                    }
                }
                submit
                Text("tasks.footer")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let shift {
                    Text(verbatim: [shift.activity.food_truck, shift.activity.name].compactMap { $0 }.joined(separator: " · "))
                } else {
                    Text("tasks.kicker")
                }
            }
            .frText(FRType.kicker)
            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text("tasks.title").frText(FRType.screenTitle)
        }
    }

    private var progressCard: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("tasks.completedLabel").frText(FRType.eyebrow)
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.6))
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(tasks.completed)")
                        .font(.system(size: 38, weight: .heavy).monospacedDigit())
                    Text("/ \(tasks.items.count)")
                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.55))
                }
                ProgressView(value: tasks.progress)
                    .tint(Color.foodrun.truck.mees)
            }
            Spacer()
            if let submittedAt {
                Text("tasks.submittedAt \(submittedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.55))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(18)
        .foregroundStyle(Color.foodrun.backgroundInverseInk)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous)
                .fill(Color.foodrun.foreground)
        )
    }

    private var sectionHeader: some View {
        HStack {
            Text("tasks.section.beforeService").frText(FRType.sectionHeader)
            Spacer()
            Text("tasks.section.tapToComplete")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private var submit: some View {
        Button {
            submittedAt = Date()
            FRHaptic.success.fire()
        } label: {
            Text("tasks.submit")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(Color.foodrun.foreground))
                .frCTAShadow()
        }
        .buttonStyle(.plain)
    }
}
