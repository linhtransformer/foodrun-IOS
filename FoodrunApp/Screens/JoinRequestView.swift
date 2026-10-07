import Supabase
import SwiftUI

// "Ask an organization to hire you", opened from the waiting screen
// (NotLinkedView). Same request as the web's /me/signup: name, date of birth and
// one or more organizations from the public directory → edge fn
// worker-self-signup creates a pending employee row per organization. The
// operator approves in HQ; the worker gets an inbox notification and the
// waiting screen clears on the next load.

struct JoinRequestView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called after a successful request so the waiting screen reloads.
    var onSent: () async -> Void

    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var organizations: [PublicOrganization] = []
    @State private var selected: Set<UUID> = []
    @State private var search = ""
    @State private var loadingOrganizations = true
    @State private var sending = false
    @State private var errorText: String?
    @State private var sentTo: [String]?

    /// The edge function refuses anyone under 15.
    private var latestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -15, to: Date()) ?? Date()
    }

    private var filtered: [PublicOrganization] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return organizations }
        return organizations.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var canSend: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selected.isEmpty && !sending
    }

    var body: some View {
        NavigationStack {
            Group {
                if let sentTo {
                    sentState(sentTo)
                } else {
                    form
                }
            }
            .background(Color.foodrun.background.ignoresSafeArea())
            .navigationTitle(Text("join.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text(sentTo == nil ? "action.cancel" : "action.close") }
                }
            }
        }
        .tint(Color.foodrun.foreground)
        .task { await load() }
    }

    // MARK: - Form

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("join.intro")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)

                AuthField(label: "join.name") {
                    TextField("join.name", text: $name)
                        .textContentType(.name)
                        .font(.system(size: 15))
                }

                AuthField(label: "join.dateOfBirth") {
                    DatePicker("join.dateOfBirth", selection: $dateOfBirth, in: ...latestBirthDate, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, FRLanguage.locale)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                organizationPicker

                if let errorText {
                    Label { Text(verbatim: errorText) } icon: { Image(systemName: "exclamationmark.circle") }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                }

                AuthPrimaryButton(title: "join.send", working: sending) {
                    Task { await send() }
                }
                .disabled(!canSend)
                .opacity(canSend || sending ? 1 : 0.4)
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var organizationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("join.organizations")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Spacer()
                if !selected.isEmpty {
                    Text(verbatim: FRLanguage.string("join.selected %lld", selected.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.foodrun.mutedForegroundSoft)
                TextField("join.search", text: $search)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))

            VStack(spacing: 0) {
                if loadingOrganizations {
                    ProgressView().padding(20)
                } else if filtered.isEmpty {
                    Text("join.noResults")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        .padding(20)
                } else {
                    ForEach(filtered) { org in
                        organizationRow(org)
                        if org.id != filtered.last?.id {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous).fill(Color.foodrun.card))
            .frNeu(.raised)
        }
    }

    private func organizationRow(_ org: PublicOrganization) -> some View {
        let isOn = selected.contains(org.id)
        return Button {
            if isOn { selected.remove(org.id) } else { selected.insert(org.id) }
            FRHaptic.light.fire()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? Color.foodrun.foreground : Color.foodrun.mutedForegroundSoft)
                Text(verbatim: org.name).frText(FRType.rowTitle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Sent

    private func sentState(_ names: [String]) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.foodrun.truck.mees))
            Text("join.sent.title")
                .font(.system(size: 22, weight: .bold))
            Text(verbatim: String(format: FRLanguage.string("join.sent.body %@"), names.joined(separator: ", ")))
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .multilineTextAlignment(.center)
            AuthPrimaryButton(title: "action.done", working: false) { dismiss() }
                .padding(.top, 8)
        }
        .padding(.horizontal, FRSpacing.screenH.value)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Data

    private func load() async {
        if name.isEmpty, let meta = try? await SupabaseManager.shared.client.auth.session.user.userMetadata {
            name = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue ?? ""
        }
        do {
            organizations = try await WorkerAPI.fetchPublicOrganizations()
        } catch {
            errorText = error.localizedDescription
        }
        loadingOrganizations = false
    }

    private func send() async {
        sending = true
        errorText = nil
        defer { sending = false }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        do {
            let result = try await WorkerAPI.requestToJoin(
                name: name.trimmingCharacters(in: .whitespaces),
                dateOfBirth: f.string(from: dateOfBirth),
                organizationIds: Array(selected)
            )
            guard result.ok else {
                errorText = message(for: result)
                FRHaptic.error.fire()
                return
            }
            FRHaptic.success.fire()
            let names = (result.pending_organization_names ?? []) + (result.approved_organization_names ?? [])
            sentTo = names.isEmpty ? organizations.filter { selected.contains($0.id) }.map(\.name) : names
            await onSent()
        } catch {
            errorText = FRLanguage.string("join.error.generic")
            FRHaptic.error.fire()
        }
    }

    private func message(for result: JoinRequestResult) -> String {
        switch result.error {
        case "too_young":
            return FRLanguage.string("join.error.tooYoung")
        case "company_not_found":
            return FRLanguage.string("join.error.companyGone")
        case "recently_declined":
            return String(format: FRLanguage.string("join.error.declined %@ %lld"),
                          result.organization_name ?? "", result.hours_until_retry ?? 24)
        case "unauthorized", "invalid_session":
            return FRLanguage.string("join.error.session")
        default:
            return FRLanguage.string("join.error.generic")
        }
    }
}
