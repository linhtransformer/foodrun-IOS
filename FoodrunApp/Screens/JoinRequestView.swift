import Supabase
import SwiftUI

// "Join an organization", opened from the waiting screen (NotLinkedView) and
// from Me. The worker types the organization code their employer gave them —
// the app never lists organizations, so nobody can browse who uses Foodrun.
// The code is looked up on the server (RPC find_organization_by_join_code),
// which returns only that one organization's name for confirmation. Then, as
// on the web's /me/signup: name + date of birth → edge fn worker-self-signup
// creates a pending employee row; the operator approves in HQ.

struct JoinRequestView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called after a successful request so the waiting screen reloads.
    var onSent: () async -> Void

    @State private var name = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var code = ""
    /// The organization the code resolved to; nil until "Check code" succeeds.
    @State private var organization: PublicOrganization?
    @State private var checking = false
    @State private var sending = false
    @State private var errorText: String?
    @State private var sentTo: [String]?

    /// The edge function refuses anyone under 15.
    private var latestBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -15, to: Date()) ?? Date()
    }

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSend: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && organization != nil && !sending
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
            AuthField(label: "join.code") {
                HStack(spacing: 10) {
                    TextField("join.code.placeholder", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .semibold).monospaced())
                        .onChange(of: code) { _, _ in organization = nil }
                        .onSubmit { Task { await checkCode() } }
                    if checking { ProgressView() }
                }
            }
            if let organization {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.foodrun.subject.positive)
                    Text(verbatim: organization.name).frText(FRType.rowTitle)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
                .frNeu(.raised)
            } else {
                Text("join.code.hint")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Button {
                    Task { await checkCode() }
                } label: {
                    Text("join.code.check")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.foodrun.foreground)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(trimmedCode.isEmpty || checking)
                .opacity(trimmedCode.isEmpty ? 0.4 : 1)
            }
        }
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
    }

    private func checkCode() async {
        guard !trimmedCode.isEmpty else { return }
        checking = true
        errorText = nil
        defer { checking = false }
        do {
            if let found = try await WorkerAPI.findOrganization(joinCode: trimmedCode) {
                organization = found
                FRHaptic.success.fire()
            } else {
                errorText = FRLanguage.string("join.code.unknown")
                FRHaptic.warning.fire()
            }
        } catch {
            errorText = FRLanguage.string("join.error.generic")
            FRHaptic.error.fire()
        }
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
                organizationIds: organization.map { [$0.id] } ?? []
            )
            guard result.ok else {
                errorText = message(for: result)
                FRHaptic.error.fire()
                return
            }
            FRHaptic.success.fire()
            let names = (result.pending_organization_names ?? []) + (result.approved_organization_names ?? [])
            sentTo = names.isEmpty ? [organization?.name ?? ""] : names
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
