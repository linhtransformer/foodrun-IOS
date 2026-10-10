import MapKit
import SafariServices
import SwiftUI

// The shift's Draaiboek and Setup — read-only, the same content the script
// portal shows (HQ decision 0038): the day's note, your day and tickets, what
// we sell, event details, locations with a map, run-of-show, links, files and
// the team. Setup is build-up and teardown. Nothing here is a task; tasks
// (operator tasks, prep checklist, stock counts) live on the Taken tab.

// MARK: - Draaiboek

struct ShiftBriefingContent: View {
    let store: EventStore
    let event: CrewEvent
    let day: String
    let onOpenDish: (CrewDish) -> Void

    @State private var opening: CrewOpenedURL?
    @State private var openError: String?
    @State private var pinning = false
    @State private var deleting: CrewLocation?

    private var briefing: CrewBriefing? { event.briefing }
    private var dishes: [CrewDish] { event.dishes ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if briefing == nil && dishes.isEmpty {
                CrewBriefingEmpty(key: "briefing.off")
            }
            if let error = openError { CrewBriefingError(text: error) }
            if let briefing {
                dayCallout(briefing)
                myDayCard(briefing)
            }
            if !dishes.isEmpty { menuCard }
            if let briefing {
                eventCard(briefing)
                locationsSection(briefing)
                ForEach(briefing.headings) { heading in headingCard(heading) }
                linksCard(briefing)
                filesCard(briefing)
                teamCard(briefing)
                if let updated = briefing.updated_at.flatMap(CrewFormat.timestamp) {
                    Text(verbatim: String(format: FRLanguage.string("briefing.updated %@"), updated))
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
        }
        .sheet(item: $opening) { CrewSafariView(url: $0.url).ignoresSafeArea() }
        .sheet(isPresented: $pinning) {
            let start = (briefing?.locations ?? []).first { $0.lat != nil && $0.lng != nil }
            CrewPinSheet(startLatitude: start?.lat, startLongitude: start?.lng) { name, lat, lng, address, notes, photo in
                await store.addPin(name: name, latitude: lat, longitude: lng, address: address, notes: notes, photo: photo)
            }
        }
        .confirmationDialog(
            FRLanguage.string("pin.deleteConfirm"),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { location in
            Button(FRLanguage.string("pin.delete"), role: .destructive) {
                Task {
                    let ok = await store.deletePin(location)
                    if ok { FRHaptic.success.fire() } else { FRHaptic.error.fire() }
                }
            }
        }
    }

    // MARK: Locations + pins

    /// The event's locations and pins, then "Locatie pinnen" so the crew can
    /// mark a spot themselves (like the script portal's Pin a Location).
    @ViewBuilder
    private func locationsSection(_ briefing: CrewBriefing) -> some View {
        let closed = event.activity.is_closed
        ForEach(Array((briefing.locations ?? []).enumerated()), id: \.offset) { _, location in
            CrewLocationCard(location: location,
                             onDelete: (location.mine ?? false) && !closed ? { deleting = location } : nil)
                // Rows are keyed by index: when a pin above is removed, the next
                // location slides into this slot — reset the card so its map
                // (initialPosition) re-centres instead of showing the old spot.
                .id(location)
        }
        if !closed {
            Button { pinning = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                    Text("pin.add")
                    Spacer()
                    Image(systemName: "plus")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                        .strokeBorder(Color.foodrun.mutedForegroundSoft.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Today

    /// The operator's comment for this day (activities.daily_comments).
    @ViewBuilder
    private func dayCallout(_ briefing: CrewBriefing) -> some View {
        if let comment = briefing.daily_comments?.first(where: { $0.date == day }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(Color.foodrun.subject.warning)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: CrewFormat.day(day)).frText(FRType.fieldLabel)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    Text(CrewFormat.linkified(comment.text)).frText(FRType.body)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.subject.warning.opacity(0.12)))
        }
    }

    /// My times and note for this day, and my tickets for it.
    @ViewBuilder
    private func myDayCard(_ briefing: CrewBriefing) -> some View {
        let note = briefing.notes.first { $0.date == day }
        let tickets = (briefing.my_tickets ?? []).filter { $0.date == day || ($0.all_days ?? false) }
        if note != nil || !tickets.isEmpty {
            CrewBriefingCard(icon: "person.crop.circle", title: "briefing.myDay") {
                if let start = note?.start_time {
                    Text(verbatim: [start, note?.end_time].compactMap { $0 }.joined(separator: " – "))
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                }
                if let comment = note?.comment {
                    Text(CrewFormat.linkified(comment)).frText(FRType.body)
                }
                if !tickets.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(tickets) { ticket in
                            CrewFileRow(file: ticket.file, icon: "ticket", subtitle: FRLanguage.string("briefing.ticket")) { open(ticket.file) }
                        }
                    }
                }
            }
        }
    }

    // MARK: What we sell

    private var menuCard: some View {
        CrewBriefingCard(icon: "fork.knife", title: "briefing.menu") {
            VStack(spacing: 0) {
                ForEach(dishes) { dish in
                    Button { onOpenDish(dish) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            CrewDishThumb(url: dish.imageURL, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: dish.name).frText(FRType.rowTitle)
                                if let allergens = dish.allergens, !allergens.isEmpty {
                                    CrewAllergenChips(allergens: allergens)
                                }
                                if let may = dish.may_contain {
                                    Text(verbatim: String(format: FRLanguage.string("briefing.mayContain %@"), may))
                                        .frText(FRType.rowSubtitle)
                                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                }
                            }
                            Spacer(minLength: 8)
                            if let price = CrewFormat.price(dish) {
                                Text(verbatim: price)
                                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if dish.id != dishes.last?.id {
                        Rectangle().fill(Color.foodrun.border).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: Event details

    @ViewBuilder
    private func eventCard(_ briefing: CrewBriefing) -> some View {
        let hours = hoursRows(briefing.hours)
        let hasAny = briefing.date != nil || !hours.isEmpty || briefing.food_truck != nil
            || briefing.overnight_stay != nil || briefing.event_notes != nil
        if hasAny {
            CrewBriefingCard(icon: "calendar", title: "briefing.event") {
                if let date = briefing.date, let range = CrewFormat.dateRange(date.start, date.end) {
                    CrewInfoRow(label: "briefing.date", value: range, note: date.comment)
                }
                if !hours.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("briefing.hours").frText(FRType.fieldLabel)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        ForEach(hours, id: \.self) { row in
                            HStack {
                                Text(verbatim: row.label)
                                Spacer()
                                Text(verbatim: row.value).monospacedDigit()
                            }
                            .frText(FRType.rowTitle)
                            .foregroundStyle(row.isToday ? Color.foodrun.foreground : Color.foodrun.mutedForegroundSoft)
                        }
                        if let comment = briefing.hours?.comment {
                            Text(CrewFormat.linkified(comment)).frText(FRType.rowSubtitle)
                                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        }
                    }
                }
                if let truck = briefing.food_truck {
                    CrewInfoRow(label: "briefing.foodTruck", value: truck, note: nil)
                }
                if let stay = briefing.overnight_stay {
                    CrewInfoRow(label: "briefing.overnight", value: stay, note: nil)
                }
                if let notes = briefing.event_notes {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("briefing.notes").frText(FRType.fieldLabel)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        Text(CrewFormat.linkified(notes)).frText(FRType.body)
                    }
                }
            }
        }
    }

    private struct HoursRow: Hashable {
        let label: String
        let value: String
        let isToday: Bool
    }

    /// One row per opening day when the event has day times, else start–end.
    private func hoursRows(_ hours: CrewBriefingHours?) -> [HoursRow] {
        guard let hours else { return [] }
        if hours.days.count > 1 {
            return hours.days.map {
                HoursRow(label: CrewFormat.day($0.date),
                         value: [$0.start, $0.end].compactMap { $0 }.joined(separator: " – "),
                         isToday: $0.date == day)
            }
        }
        let start = hours.days.first?.start ?? hours.start
        let end = hours.days.first?.end ?? hours.end
        guard start != nil || end != nil else { return [] }
        return [HoursRow(label: FRLanguage.string("briefing.hours.every"),
                         value: [start, end].compactMap { $0 }.joined(separator: " – "),
                         isToday: true)]
    }

    // MARK: Run-of-show

    /// A script heading: the same card as the others, with the icon the
    /// operator picked for it in the script editor.
    private func headingCard(_ heading: CrewHeading) -> some View {
        CrewBriefingCard(icon: CrewFormat.headingSymbol(heading.icon), verbatim: heading.name) {
            if let content = heading.content {
                Text(CrewFormat.linkified(content)).frText(FRType.body)
                    .foregroundStyle(Color.foodrun.bodySoft)
            }
            ForEach(heading.images ?? []) { image in
                CrewRemoteImage(url: CrewAPI.publicURL(image))
                    .onTapGesture { open(image) }
            }
            if let attachments = heading.attachments, !attachments.isEmpty {
                VStack(spacing: 0) {
                    ForEach(attachments) { file in
                        CrewFileRow(file: file, icon: "doc.richtext", subtitle: nil) { open(file) }
                    }
                }
            }
        }
    }

    // MARK: Links, files, team

    @ViewBuilder
    private func linksCard(_ briefing: CrewBriefing) -> some View {
        if let links = briefing.links, !links.isEmpty {
            CrewBriefingCard(icon: "link", title: "briefing.links") {
                VStack(spacing: 0) {
                    ForEach(links) { link in
                        Button {
                            if let url = URL(string: link.url) { opening = CrewOpenedURL(url: url) }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: link.title).frText(FRType.rowTitle)
                                    Text(verbatim: URL(string: link.url)?.host ?? link.url)
                                        .frText(FRType.rowSubtitle)
                                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(Color.foodrun.mutedForegroundSoft)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func filesCard(_ briefing: CrewBriefing) -> some View {
        let myTickets = briefing.my_tickets ?? []
        let myFiles = briefing.my_files ?? []
        let unnamed = briefing.unnamed_tickets ?? []
        let files = briefing.files ?? []
        if !(myTickets.isEmpty && myFiles.isEmpty && unnamed.isEmpty && files.isEmpty) {
            CrewBriefingCard(icon: "ticket", title: "briefing.tickets") {
                VStack(spacing: 0) {
                    ForEach(myTickets) { ticket in
                        CrewFileRow(file: ticket.file, icon: "ticket", subtitle: ticketSubtitle(ticket)) { open(ticket.file) }
                    }
                    ForEach(myFiles) { file in
                        CrewFileRow(file: file, icon: "person.text.rectangle", subtitle: FRLanguage.string("briefing.myFile")) { open(file) }
                    }
                    ForEach(files) { file in
                        CrewFileRow(file: file, icon: "doc", subtitle: FRLanguage.string("briefing.eventFile")) { open(file) }
                    }
                    ForEach(unnamed) { file in
                        CrewFileRow(file: file, icon: "ticket", subtitle: FRLanguage.string("briefing.unnamedTicket")) { open(file) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func teamCard(_ briefing: CrewBriefing) -> some View {
        if let team = briefing.team?.first(where: { $0.date == day }), !team.names.isEmpty {
            CrewBriefingCard(icon: "person.3", title: "briefing.team") {
                CrewFlowChips(items: team.names)
            }
        }
    }

    private func ticketSubtitle(_ ticket: CrewTicket) -> String? {
        if ticket.all_days ?? false { return FRLanguage.string("briefing.allDays") }
        return ticket.date.map { CrewFormat.day($0) }
    }

    // MARK: Opening files

    private func open(_ file: CrewFile) {
        Task {
            do {
                opening = CrewOpenedURL(url: try await CrewAPI.fileURL(file))
                openError = nil
            } catch {
                openError = FRLanguage.string("briefing.fileError")
                FRHaptic.error.fire()
            }
        }
    }
}

// MARK: - Setup (build-up and teardown)

struct ShiftSetupContent: View {
    let briefing: CrewBriefing?

    @State private var opening: CrewOpenedURL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if briefing?.setup == nil && briefing?.teardown == nil && briefing?.electricity == nil {
                CrewBriefingEmpty(key: "setup.none")
            }
            if let setup = briefing?.setup { block(setup, icon: "wrench.and.screwdriver", title: "setup.buildUp") }
            if let power = briefing?.electricity { CrewPowerCard(power: power) }
            if let teardown = briefing?.teardown { block(teardown, icon: "shippingbox", title: "setup.teardown") }
        }
        .sheet(item: $opening) { CrewSafariView(url: $0.url).ignoresSafeArea() }
    }

    private func block(_ b: CrewSetupBlock, icon: String, title: LocalizedStringKey) -> some View {
        CrewBriefingCard(icon: icon, title: title) {
            if let note = b.note {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "megaphone.fill").foregroundStyle(Color.foodrun.subject.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("setup.attention").frText(FRType.fieldLabel)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        Text(CrewFormat.linkified(note)).frText(FRType.body)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.foodrun.subject.warning.opacity(0.12)))
            }
            if let date = b.date.flatMap(CrewFormat.longDay) {
                CrewInfoRow(label: "briefing.date", value: date, note: nil)
            }
            if b.start != nil || b.end != nil {
                CrewInfoRow(label: "setup.time", value: [b.start, b.end].compactMap { $0 }.joined(separator: " – "), note: nil)
            }
            if let comments = b.comments {
                Text(CrewFormat.linkified(comments)).frText(FRType.body)
            }
            ForEach(b.images ?? []) { image in
                CrewRemoteImage(url: CrewAPI.publicURL(image))
                    .onTapGesture { if let url = CrewAPI.publicURL(image) { opening = CrewOpenedURL(url: url) } }
            }
        }
    }
}

// MARK: - Stroomplan

/// The electricity plan: which line (230 V / 16 A / 32 A), what's plugged into
/// each outlet, and the load — same maths as HQ's StroomplanPreview (3680 W
/// per outlet; an appliance split over outlets shares its wattage).
struct CrewPowerCard: View {
    let power: CrewPower

    private static let outletWatts = 3680.0

    var body: some View {
        CrewBriefingCard(icon: "bolt.fill", title: "power.title") {
            let counts = countLabels
            if !counts.isEmpty {
                CrewFlowChips(items: counts)
            }
            ForEach(Array(power.lines.enumerated()), id: \.offset) { index, line in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(verbatim: String(format: FRLanguage.string("power.line %lld"), index + 1) + " · " + lineLabel(line.type))
                            .frText(FRType.rowTitle)
                        Spacer()
                        Text(verbatim: "\(Int(lineWatts(line).rounded())) / \(Int(Self.outletWatts) * outletCount(line.type)) W")
                            .frText(FRType.rowSubtitle).monospacedDigit()
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    ForEach(Array(line.outlets.enumerated()), id: \.offset) { outletIndex, outlet in
                        let watts = outletWatts(line, outlet)
                        let over = watts > Self.outletWatts
                        HStack(alignment: .top, spacing: 10) {
                            Text(verbatim: "\(outletIndex + 1)")
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(over ? Color.foodrun.subject.destructive.opacity(0.15) : Color.foodrun.neuTrack))
                            VStack(alignment: .leading, spacing: 2) {
                                if outlet.items.isEmpty {
                                    Text("power.empty").frText(FRType.rowSubtitle)
                                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                }
                                ForEach(Array(outlet.items.enumerated()), id: \.offset) { _, item in
                                    Text(verbatim: itemLabel(line, item)).frText(FRType.rowSubtitle)
                                }
                            }
                            Spacer(minLength: 8)
                            Text(verbatim: "\(Int(watts.rounded())) W")
                                .frText(FRType.rowSubtitle).monospacedDigit()
                                .foregroundStyle(over ? Color.foodrun.subject.destructive : Color.foodrun.mutedForegroundSoft)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.background))
            }
            if let comment = power.comment {
                Text(CrewFormat.linkified(comment)).frText(FRType.body)
            }
        }
    }

    private var countLabels: [String] {
        var out: [String] = []
        if let n = power.v230, n > 0 { out.append("\(n) × 230 V") }
        if let n = power.a16, n > 0 { out.append("\(n) × 16 A") }
        if let n = power.a32, n > 0 { out.append("\(n) × 32 A") }
        return out
    }

    private func lineLabel(_ type: String) -> String {
        switch type {
        case "16a": return FRLanguage.string("power.type.16a")
        case "32a": return FRLanguage.string("power.type.32a")
        default: return FRLanguage.string("power.type.230v")
        }
    }

    private func outletCount(_ type: String) -> Int {
        switch type {
        case "16a": return 3
        case "32a": return 6
        default: return 1
        }
    }

    /// Outlets of this line an appliance is split over (1 when not split).
    private func slices(_ line: CrewPowerLine, _ item: CrewPowerItem) -> Double {
        guard let split = item.split_id else { return 1 }
        let n = line.outlets.filter { $0.items.contains { $0.split_id == split } }.count
        return Double(max(n, 1))
    }

    private func itemWatts(_ line: CrewPowerLine, _ item: CrewPowerItem) -> Double {
        item.watts * item.quantity / slices(line, item)
    }

    private func outletWatts(_ line: CrewPowerLine, _ outlet: CrewPowerOutlet) -> Double {
        outlet.items.reduce(0) { $0 + itemWatts(line, $1) }
    }

    private func lineWatts(_ line: CrewPowerLine) -> Double {
        line.outlets.reduce(0) { $0 + outletWatts(line, $1) }
    }

    private func itemLabel(_ line: CrewPowerLine, _ item: CrewPowerItem) -> String {
        let n = slices(line, item)
        let split = n > 1 ? " (1/\(Int(n)))" : ""
        return "\(CrewFormat.number(item.quantity))× \(item.name)\(split) · \(Int(itemWatts(line, item).rounded())) W"
    }
}

// MARK: - Building blocks

/// A titled card on the off-white ground (same surface as the task cards).
struct CrewBriefingCard<Content: View>: View {
    let icon: String
    let title: Text
    let content: Content

    init(icon: String, title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = Text(title)
        self.content = content()
    }

    /// Operator-written title (a script heading): shown as typed.
    init(icon: String, verbatim title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = Text(verbatim: title)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.foodrun.neuTrack))
                title.frText(FRType.sectionHeader)
                Spacer(minLength: 0)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.foodrun.foreground)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raised)
    }
}

struct CrewInfoRow: View {
    let label: LocalizedStringKey
    let value: String
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text(CrewFormat.linkified(value)).frText(FRType.rowTitle)
            if let note {
                Text(CrewFormat.linkified(note)).frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }
}

/// One location: map with a pin (when it has coordinates), name, address,
/// notes and a Route button that opens Apple Maps.
struct CrewLocationCard: View {
    let location: CrewLocation
    /// Set for a pin I placed: shows a remove button.
    var onDelete: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = location.lat, let lng = location.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, latitudinalMeters: 700, longitudinalMeters: 700))) {
                    Marker(location.name ?? location.address ?? "", coordinate: coordinate)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .allowsHitTesting(false)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("briefing.location").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    if let name = location.name { Text(verbatim: name).frText(FRType.rowTitle) }
                    if let address = location.address {
                        Text(verbatim: address)
                            .frText(location.name == nil ? FRType.rowTitle : FRType.rowSubtitle)
                            .foregroundStyle(location.name == nil ? Color.foodrun.foreground : Color.foodrun.mutedForegroundSoft)
                    }
                }
                Spacer(minLength: 8)
                if routeURL != nil {
                    Button { if let url = routeURL { openURL(url) } } label: {
                        Text("detail.route")
                            .frText(FRType.segmented)
                            .foregroundStyle(Color.foodrun.backgroundInverseInk)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(Color.foodrun.foreground))
                    }
                    .buttonStyle(.plain)
                }
            }
            if let notes = location.notes {
                Text(CrewFormat.linkified(notes)).frText(FRType.body)
            }
            if let image = location.image, let url = URL(string: image) {
                CrewRemoteImage(url: url)
            }
            if location.added_by != nil || onDelete != nil {
                HStack(spacing: 8) {
                    if let by = location.added_by {
                        Label(String(format: FRLanguage.string("pin.addedBy %@"), by), systemImage: "mappin")
                            .frText(FRType.rowSubtitle)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    Spacer(minLength: 8)
                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.foodrun.subject.destructive)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("pin.delete"))
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.foodrun.foreground)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private var routeURL: URL? {
        if let lat = location.lat, let lng = location.lng {
            return URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)")
        }
        guard let address = location.address?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "http://maps.apple.com/?daddr=\(address)")
    }
}

struct CrewFileRow: View {
    let file: CrewFile
    let icon: String
    let subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.foodrun.neuTrack))
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: file.name).frText(FRType.rowTitle).lineLimit(1)
                    if let subtitle {
                        Text(verbatim: subtitle).frText(FRType.rowSubtitle)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct CrewRemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Rectangle().fill(Color.foodrun.neuTrack)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

struct CrewAllergenChips: View {
    let allergens: [String]

    var body: some View {
        CrewFlowChips(items: allergens.map(CrewFormat.allergen), small: true)
    }
}

/// Chips that wrap onto the next line.
struct CrewFlowChips: View {
    let items: [String]
    var small = false

    var body: some View {
        CrewWrapLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(verbatim: item)
                    .font(.system(size: small ? 11 : 13, weight: .semibold))
                    .padding(.horizontal, small ? 8 : 10).padding(.vertical, small ? 3 : 6)
                    .background(Capsule().fill(Color.foodrun.neuTrack))
            }
        }
    }
}

/// Minimal wrapping layout (iOS 16+ Layout).
struct CrewWrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct CrewBriefingEmpty: View {
    let key: String

    var body: some View {
        Text(verbatim: FRLanguage.string(key))
            .frText(FRType.rowSubtitle)
            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

struct CrewBriefingError: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
            Text(verbatim: text)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.foodrun.subject.destructive)
    }
}

// MARK: - In-app browser (links, PDFs, photos)

struct CrewOpenedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct CrewSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
