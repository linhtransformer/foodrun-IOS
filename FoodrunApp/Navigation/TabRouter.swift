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

    public var addShiftOpen: Bool = false

    public enum Route: Hashable {
        case shiftDetail(activityId: UUID, date: Date)
        /// The shift screen opened on its Taken tab (from the Tasks tab).
        case event(activityId: UUID, date: Date)
        /// A colleague's shift from the Rooster view: view only.
        case colleagueShift(TeamShift)
        case tasks
        case approvedHours
        /// Ruilen: offers, open shifts, my shifts to offer.
        case swaps
        /// Verlof: ask for days off, see decisions.
        case leave
        /// Ik → Instellingen.
        case settings
        /// Ik → Jouw organisaties, while no employer has added this account yet:
        /// how to get added (email to share, join by code, check again).
        case organizations
    }

    public func pushOnShifts(_ route: Route) { shiftsPath.append(route) }
    public func popOnShifts() { if !shiftsPath.isEmpty { shiftsPath.removeLast() } }
}
