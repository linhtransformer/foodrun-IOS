import SwiftUI

// How to get added by an employer, for an account that isn't linked to one yet —
// e.g. a worker who made an account in the app first. Opened from Ik → Jouw
// organisaties (the tabs stay usable without an employer). The
// employer adds them in Foodrun HQ → Stakeholders → "Add employee" with this
// email; HQ shows "has a Foodrun account" (RPC find_worker_account) and the
// row links on save. "Check again" re-runs the link + load.

struct NotLinkedView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(ScheduleStore.self) private var schedule
    @Environment(\.dismiss) private var dismiss
    var onRefresh: () async -> Void
    /// Pushed from Ik: back button, and no account rows (Ik has those already).
    var asPage = false
    @State private var showJoin = false

    private var email: String {
        if case .signedIn(let email) = auth.state { return email }
        return ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if asPage { backButton }
                Image(systemName: "person.badge.clock")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color.foodrun.truck.mees))
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("notLinked.title")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.6)
                    Text(schedule.hasPendingRequest ? "notLinked.pending" : "notLinked.body")
                        .frText(FRType.body)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }

                // Join with the organization code from your employer (off until
                // HQ hands out codes — AppConfig.Features.joinByCode).
                if AppConfig.Features.joinByCode {
                    AuthPrimaryButton(
                        title: schedule.hasPendingRequest ? "notLinked.askAnother" : "notLinked.ask",
                        working: false
                    ) {
                        showJoin = true
                    }
                }

                Button {
                    Task { await onRefresh() }
                } label: {
                    ZStack {
                        if schedule.isLoading {
                            ProgressView()
                        } else {
                            Text("notLinked.checkAgain")
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(schedule.isLoading)

                if AppConfig.Features.joinByCode {
                    Text("notLinked.orByEmail")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        .padding(.top, 8)
                }

                emailCard

                steps

                if !asPage {
                    ProfileAccountSection(showsJoinRow: false)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, asPage ? FRSpacing.screenTop.value : 60)
            .padding(.bottom, asPage ? FRSpacing.screenBottom.value : 40)
        }
        .refreshable { await onRefresh() }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Added by an employer while this page is open ("Check again"): back to Ik,
        // which now lists the organization.
        .onChange(of: schedule.isUnlinked) { _, unlinked in
            if asPage && !unlinked { dismiss() }
        }
        .sheet(isPresented: $showJoin) {
            JoinRequestView(onSent: onRefresh)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.foodrun.card))
                .frNeu(.raised)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("action.back"))
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("notLinked.yourEmail")
                .frText(FRType.fieldLabel)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text(verbatim: email)
                .font(.system(size: 17, weight: .semibold))
                .textSelection(.enabled)
            ShareLink(item: String(format: FRLanguage.string("notLinked.shareMessage %@"), email)) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("notLinked.share")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: FRRadius.container.value).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "notLinked.step1")
            step(2, "notLinked.step2")
            step(3, "notLinked.step3")
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.foodrun.card))
            Text(text).frText(FRType.rowSubtitle)
            Spacer(minLength: 0)
        }
    }
}
