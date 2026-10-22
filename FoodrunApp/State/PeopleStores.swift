import Foundation
import SwiftUI

// Ruilen and Verlof — loaded with the rest on sign-in and on returning to the app.
// Writes reload the board so what HQ decided (or a colleague did) shows straight away.

@MainActor
@Observable
public final class SwapStore {
    public var board = SwapBoard()
    /// The published roster of my employers for the days the Rooster tab asked for.
    public var team: [TeamShift] = []
    /// False when the team roster couldn't load — the Rooster tab then falls back to my own shifts.
    public var teamLoaded = false
    /// The day the team roster was last loaded around; writes reload that week.
    private var teamAnchor: Date?
    public var isLoading = false
    public var busy = false
    public var lastError: String?

    /// What waits for my answer: offers to me and colleagues asking for my shift (Inbox badge).
    public var attentionCount: Int { board.offered.count + board.asked.count }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            board = try await PeopleAPI.swapBoard()
            lastError = nil
        } catch {
            lastError = PeopleAPI.message(for: error)
        }
    }

    /// The board entry for one of my shifts (activity × day), if it's still coming.
    public func myShift(activityId: UUID, day: String) -> SwapShift? {
        board.my_shifts.first { $0.activity.id == activityId && $0.day == day }
    }

    public func team(on day: String) -> [TeamShift] {
        team.filter { $0.day == day }
    }

    public func openShifts(on day: String) -> [OpenShift] {
        board.open_shifts.filter { $0.day == day }
    }

    /// The week around `day` (Mon–Sun), so swiping through the carousel doesn't reload per day.
    public func loadTeam(around day: Date) async {
        teamAnchor = day
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current
        let monday = cal.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? day
        do {
            team = try await PeopleAPI.teamRoster(from: SchemaDates.string(monday), to: SchemaDates.string(sunday))
            teamLoaded = true
        } catch {
            teamLoaded = false
        }
    }

    public func colleagues(ownerId: UUID) -> [SwapColleague] {
        board.colleagues.filter { $0.owner_id == ownerId }
    }

    @discardableResult
    public func offer(activityId: UUID, day: String, to colleague: UUID?, note: String) async -> Bool {
        await run { try await PeopleAPI.offerShift(activityId: activityId, day: day, to: colleague, note: note.isEmpty ? nil : note) }
    }

    @discardableResult
    public func respond(_ offer: SwapOffer, accept: Bool) async -> Bool {
        await run { _ = try await PeopleAPI.respond(requestId: offer.id, accept: accept) }
    }

    /// Give my shift to the colleague who asked (accept) or keep it.
    @discardableResult
    public func answer(_ ask: SwapAsk, give: Bool) async -> Bool {
        await run { _ = try await PeopleAPI.respond(requestId: ask.id, accept: give) }
    }

    /// Ask a colleague for their shift.
    @discardableResult
    public func askTakeover(_ shift: TeamShift, note: String) async -> Bool {
        await run {
            try await PeopleAPI.askTakeover(activityId: shift.activity.id, day: shift.day, from: shift.employee_id,
                                            note: note.isEmpty ? nil : note)
        }
    }

    @discardableResult
    public func pickUp(_ shift: OpenShift) async -> Bool {
        await run { _ = try await PeopleAPI.requestOpenShift(activityId: shift.activity.id, day: shift.day) }
    }

    @discardableResult
    public func withdraw(requestId: UUID) async -> Bool {
        await run { try await PeopleAPI.withdrawSwap(requestId: requestId) }
    }

    private func run(_ work: () async throws -> Void) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            try await work()
            lastError = nil
            await load()
            if let teamAnchor { await loadTeam(around: teamAnchor) }
            return true
        } catch {
            lastError = PeopleAPI.message(for: error)
            return false
        }
    }
}

@MainActor
@Observable
public final class LeaveStore {
    public var requests: [DBLeaveRequest] = []
    public var isLoading = false
    public var busy = false
    public var lastError: String?

    /// My employee rows (one per employer) — set by the screen from ScheduleStore.
    public var employeeIds: [UUID] = []

    public func load(employeeIds ids: [UUID]? = nil) async {
        if let ids { employeeIds = ids }
        isLoading = true
        defer { isLoading = false }
        do {
            requests = try await PeopleAPI.myLeave(employeeIds: employeeIds)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    public func ask(employeeId: UUID, from: Date, to: Date, reason: String) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            try await PeopleAPI.askLeave(employeeId: employeeId, from: SchemaDates.string(from), to: SchemaDates.string(max(from, to)),
                                         reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
            await load()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func withdraw(_ request: DBLeaveRequest) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            try await PeopleAPI.withdrawLeave(id: request.id)
            await load()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
