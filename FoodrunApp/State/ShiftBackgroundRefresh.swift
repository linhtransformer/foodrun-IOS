import BackgroundTasks
import Foundation

// Checks the roster for shift edits while the app is closed, so the
// ShiftChangeStore notification can arrive without opening the app. iOS decides
// when a refresh actually runs (typically every few hours, based on use).

enum ShiftBackgroundRefresh {
    static let taskId = "nl.foodrun.app.shift-refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func run() async {
        schedule()   // keep the chain going
        guard let userId = try? await WorkerAPI.currentUserId() else { return }
        let roster = ScheduleStore()
        await roster.load()
        guard roster.rosterLoaded else { return }
        ShiftChangeStore().track(roster.shifts, today: SchemaDates.string(Date()), userId: userId)
    }
}
