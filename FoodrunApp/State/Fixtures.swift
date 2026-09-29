import Foundation

// Fixture data for #Preview only. Shapes match the real tables (SharedSchema.swift)
// so previews exercise the same code paths as live data. AppShell loads live
// data from Supabase on sign-in; nothing here ships to users.

enum Fixtures {
    static let calendar = Calendar(identifier: .gregorian)

    static var today: Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 9
        comps.day = 16   // Wed 16 Sep — the day the prototype centers on
        comps.hour = 14
        return calendar.date(from: comps) ?? Date()
    }

    private static func day(_ offset: Int) -> String {
        SchemaDates.string(calendar.date(byAdding: .day, value: offset, to: today) ?? today)
    }

    static let worker = DBEmployee(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        user_id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        auth_user_id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        name: "Sanne",
        last_name: "Vermeer",
        email: "sanne@vietnamama.nl",
        phone: nil,
        hourly_rate: 16,
        roles: ["Kitchen"],
        contract_type: "ovo",
        approval_status: "approved",
        onboarded_at: today
    )

    private static var workerKey: String { worker.id.uuidString.lowercased() }

    static let activityMees = DBActivity(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000A01")!,
        user_id: worker.user_id,
        name: "Paradigm Festival",
        start_date: day(0),
        end_date: day(4),
        start_time: "19:00",
        end_time: "23:00",
        location: "Steenwijkerdiep 32, Steenwijk",
        color: "#FBE27A",
        food_truck: "Truck Mees",
        daily_times: [day(2): DBDayTimes(startTime: "12:00", endTime: "22:00", active: true)],
        daily_employee_times: nil,
        daily_employees: [day(0): [workerKey], day(2): [workerKey], day(4): [workerKey]],
        employees: nil,
        crew_counts: [day(0): 3, day(2): 2]
    )

    static let activityMama = DBActivity(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000A02")!,
        user_id: worker.user_id,
        name: "Zwarte Cross",
        start_date: day(6),
        end_date: day(8),
        start_time: "11:00",
        end_time: "23:00",
        location: "Lichtenvoorde",
        color: "#F0A8C8",
        food_truck: "Truck Mama",
        daily_times: nil,
        daily_employee_times: [day(7): [workerKey: DBDayTimes(startTime: "15:00", endTime: "23:00", active: true)]],
        daily_employees: nil,
        employees: [workerKey],
        crew_counts: nil
    )

    static let hoursPending = DBEmployeeHours(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000B01")!,
        employee_id: worker.id,
        activity_id: activityMees.id,
        work_date: day(-2),
        hours: 6.3,
        break_minutes: 30,
        comment: nil,
        status: .pending,
        submitted_at: today,
        approved_by: nil,
        approved_at: nil,
        rejected_reason: nil
    )

    static let inbox: [DBWorkerNotification] = [
        DBWorkerNotification(
            id: UUID(),
            user_id: worker.auth_user_id!,
            activity_id: activityMees.id,
            type: .activity_added,
            title: "Nieuwe dienst",
            body: "Paradigm Festival · 19:00 – 23:00",
            url: nil,
            is_read: false,
            operator_name: "Vietnamama",
            created_at: today
        ),
        DBWorkerNotification(
            id: UUID(),
            user_id: worker.auth_user_id!,
            activity_id: activityMees.id,
            type: .hours_approved,
            title: "Uren goedgekeurd",
            body: "6,3 u voor ma 14 sep",
            url: nil,
            is_read: false,
            operator_name: "Vietnamama",
            created_at: calendar.date(byAdding: .hour, value: -3, to: today) ?? today
        ),
    ]

    static let checklist: [DBTaskItem] = [
        item(1, "Prep station ready", note: "Wipe surface, stock cutlery, load napkins."),
        item(2, "Gas bottles connected", note: "Two full bottles + regulator seal."),
        item(3, "Opening stock counted", note: "Enter counts before service.", requiresValue: true),
        item(4, "Fridge temperature", note: "Log ≤ 4,0 °C.", requiresValue: true),
        item(5, "POS test", note: "One trial order + refund on Vietnamama POS."),
        item(6, "Closing waste weighed", note: "Kg logged before hand-in.", requiresValue: true),
        item(7, "Truck-clean photo", note: "Photo of interior + fryer.", requiresPhoto: true),
    ]

    private static func item(_ order: Int, _ title: String, note: String,
                             requiresValue: Bool = false, requiresPhoto: Bool = false) -> DBTaskItem {
        DBTaskItem(
            id: UUID(),
            task_id: nil,
            title: title,
            note: note,
            requires_value: requiresValue,
            requires_photo: requiresPhoto,
            value: nil,
            photo_url: nil,
            completed_at: nil,
            order: order
        )
    }
}
