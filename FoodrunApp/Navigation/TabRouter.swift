import SwiftUI

// Owns the current tab + a screen stack per tab. Bundle §Tab bar drives which
// tab is active; per-tab NavigationStack owns pushed detail/sheet routes.

@MainActor
@Observable
public final class TabRouter {
    public var tab: FRTab = .shifts
    public var shiftsPath: [Route] = []
    public var tasksPath: [Route] = []
    public var hoursPath: [Route] = []
    public var inboxPath: [Route] = []
    public var mePath: [Route] = []

    public var swapSheetOpen: Bool = false
    public var addShiftOpen: Bool = false

    public enum Route: Hashable {
        case shiftDetail(activityId: UUID, date: Date)
        case tasks
        case approvedHours
    }

    public func pushOnShifts(_ route: Route) { shiftsPath.append(route) }
    public func popOnShifts() { if !shiftsPath.isEmpty { shiftsPath.removeLast() } }
}
