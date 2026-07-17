import SwiftUI
import UIKit
import Auth

fileprivate enum CaregiverAlertsAvailability: Equatable {
    case cloud
    case guest
    case unavailable
}

/// Profile section: link a caregiver LINE account for missed-dose alerts.
struct CaregiverAlertsCard: View {
    @Environment(AuthService.self) private var auth
    @State private var viewModel: CaregiverAlertsViewModel
    @State private var showDisconnectConfirmation = false
    private let loadsRemoteState: Bool
    private let previewAvailability: CaregiverAlertsAvailability?

    init() {
        _viewModel = State(initialValue: CaregiverAlertsViewModel())
        loadsRemoteState = true
        previewAvailability = nil
    }

    fileprivate init(
        previewState: CaregiverAlertsViewModel.ConnectionState,
        availability: CaregiverAlertsAvailability = .cloud
    ) {
        _viewModel = State(
            initialValue: CaregiverAlertsViewModel(connectionState: previewState)
        )
        loadsRemoteState = false
        previewAvailability = availability
    }

    private var accessToken: String? {
        auth.session?.accessToken
    }

    private var isGuestMode: Bool {
        previewAvailability == .guest || (previewAvailability == nil && auth.isGuest)
    }

    private var isCloudConfigured: Bool {
        switch previewAvailability {
        case .cloud, .guest:
            true
        case .unavailable:
            false
        case nil:
            SupabaseConfig.isConfigured
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MVSectionHeader(title: "Caregiver alerts", systemImage: "message.fill")

            VStack(alignment: .leading, spacing: 16) {
                header

                Text("If a dose is still untaken after 30 minutes, your caregiver receives one LINE message.")
                    .font(.body)
                    .foregroundStyle(Color.mvSubtle)

                privacyNotice

                if isGuestMode {
                    guestContent
                } else if !isCloudConfigured {
                    unavailableContent
                } else {
                    cloudContent
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .task(id: accessToken) {
            guard loadsRemoteState,
                  !isGuestMode,
                  isCloudConfigured,
                  let accessToken
            else { return }
            await viewModel.refreshStatus(accessToken: accessToken)
        }
        .sheet(item: $viewModel.invite) { invite in
            CaregiverInviteSheet(
                invite: invite,
                checkConnection: {
                    guard let accessToken else { return false }
                    return await viewModel.refreshStatus(accessToken: accessToken)
                }
            )
        }
        .confirmationDialog(
            "Disconnect caregiver?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect caregiver", role: .destructive) {
                guard let accessToken else { return }
                Task { await viewModel.disconnect(accessToken: accessToken) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your caregiver will no longer receive missed-dose alerts.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 13) {
            MVIconTile(
                systemImage: viewModel.connectionState == .linked
                    ? "checkmark.message.fill"
                    : "message.fill",
                tint: viewModel.connectionState == .linked ? .mvSuccess : .mvAccent,
                size: 46
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("LINE caregiver alerts")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.mvInk)

                statusBadge
            }

            Spacer(minLength: 0)
        }
    }

    private var statusBadge: some View {
        Group {
            if isGuestMode {
                MVStatusBadge(
                    title: "Sign-in required",
                    systemImage: "lock.fill",
                    tint: .mvWarning
                )
            } else if !isCloudConfigured {
                MVStatusBadge(
                    title: "Unavailable",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .mvWarning
                )
            } else {
                switch viewModel.connectionState {
                case .loading:
                    MVStatusBadge(
                        title: "Checking connection",
                        systemImage: "arrow.clockwise",
                        tint: .mvAccent
                    )
                case .unlinked:
                    MVStatusBadge(
                        title: "No caregiver linked",
                        systemImage: "link",
                        tint: .mvSubtle
                    )
                case .linked:
                    MVStatusBadge(
                        title: "Caregiver connected",
                        systemImage: "checkmark.circle.fill",
                        tint: .mvSuccess
                    )
                case .error:
                    MVStatusBadge(
                        title: "Unavailable",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .mvWarning
                    )
                }
            }
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mvAccent)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            Text("Only your display name, medicine name, dosage, and scheduled time are shared. Photos are never sent.")
                .font(.subheadline)
                .foregroundStyle(Color.mvInk)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.mvAccent.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var guestContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            inlineNotice(
                "Sign in to connect a caregiver. Medicines already saved on this device will remain here.",
                tint: .mvWarning,
                systemImage: "person.crop.circle.badge.exclamationmark"
            )

            Button("Sign in to connect") {
                Task { try? await auth.signOut() }
            }
            .buttonStyle(MVPrimaryButtonStyle())
            .accessibilityHint("Leaves guest mode and opens the sign-in screen.")
        }
    }

    private var unavailableContent: some View {
        inlineNotice(
            "Caregiver alerts are unavailable right now. Please try again later.",
            tint: .mvWarning,
            systemImage: "exclamationmark.triangle.fill"
        )
    }

    @ViewBuilder
    private var cloudContent: some View {
        if viewModel.hasRequestError {
            inlineNotice(
                "Caregiver alerts could not be updated. Check your connection and try again.",
                tint: .mvDanger,
                systemImage: "exclamationmark.circle.fill"
            )
        }

        if viewModel.didDisconnect {
            inlineNotice(
                "Caregiver disconnected. Missed-dose alerts have stopped.",
                tint: .mvSuccess,
                systemImage: "checkmark.circle.fill"
            )
        }

        switch viewModel.connectionState {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Color.mvAccent)
                Text("Checking caregiver connection…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mvSubtle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)

        case .unlinked:
            Button {
                guard let accessToken else { return }
                Task { await viewModel.createInvite(accessToken: accessToken) }
            } label: {
                workingLabel(title: "Connect caregiver", systemImage: "link.badge.plus")
            }
            .buttonStyle(MVPrimaryButtonStyle(enabled: !viewModel.isWorking))
            .disabled(viewModel.isWorking || accessToken == nil)

        case .linked:
            VStack(spacing: 10) {
                Button {
                    guard let accessToken else { return }
                    Task { await viewModel.createInvite(accessToken: accessToken) }
                } label: {
                    workingLabel(title: "Replace caregiver", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(MVSecondaryButtonStyle(tint: .mvAccent))
                .disabled(viewModel.isWorking || accessToken == nil)

                Button("Disconnect caregiver", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .buttonStyle(MVSecondaryButtonStyle(tint: .mvDanger))
                .disabled(viewModel.isWorking)
            }

        case .error:
            Button {
                guard let accessToken else { return }
                Task { await viewModel.refreshStatus(accessToken: accessToken) }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(MVSecondaryButtonStyle(tint: .mvAccent))
            .disabled(viewModel.isWorking || accessToken == nil)
        }
    }

    private func inlineNotice(
        _ title: LocalizedStringKey,
        tint: Color,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                tint.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    private func workingLabel(title: LocalizedStringKey, systemImage: String) -> some View {
        ZStack {
            Label(title, systemImage: systemImage)
                .opacity(viewModel.isWorking ? 0 : 1)
            if viewModel.isWorking {
                ProgressView()
                    .tint(viewModel.connectionState == .unlinked ? Color.mvOnAccent : Color.mvAccent)
            }
        }
    }
}

@MainActor
@Observable
fileprivate final class CaregiverAlertsViewModel {
    enum ConnectionState: Equatable {
        case loading
        case unlinked
        case linked
        case error
    }

    var connectionState: ConnectionState
    var invite: CaregiverInvitePresentation?
    var isWorking = false
    var hasRequestError = false
    var didDisconnect = false

    init(connectionState: ConnectionState = .loading) {
        self.connectionState = connectionState
    }

    @discardableResult
    func refreshStatus(accessToken: String) async -> Bool {
        do {
            let status = try await CaregiverAlertService.fetchStatus(accessToken: accessToken)
            connectionState = status.linked ? .linked : .unlinked
            hasRequestError = false
            if status.linked {
                invite = nil
            }
            return status.linked
        } catch {
            hasRequestError = true
            if connectionState == .loading {
                connectionState = .error
            }
            return false
        }
    }

    func createInvite(accessToken: String) async {
        isWorking = true
        hasRequestError = false
        didDisconnect = false
        defer { isWorking = false }

        do {
            let response = try await CaregiverAlertService.createInvite(accessToken: accessToken)
            invite = CaregiverInvitePresentation(
                code: response.code,
                expiresAt: Self.parseExpiration(response.expiresAt)
            )
        } catch {
            hasRequestError = true
        }
    }

    func disconnect(accessToken: String) async {
        isWorking = true
        hasRequestError = false
        didDisconnect = false
        defer { isWorking = false }

        do {
            try await CaregiverAlertService.unlink(accessToken: accessToken)
            connectionState = .unlinked
            invite = nil
            didDisconnect = true
        } catch {
            hasRequestError = true
        }
    }

    private static func parseExpiration(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? Date().addingTimeInterval(15 * 60)
    }
}

fileprivate struct CaregiverInvitePresentation: Identifiable {
    let code: String
    let expiresAt: Date

    var id: String { code }
}

private struct CaregiverInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    let invite: CaregiverInvitePresentation
    let checkConnection: () async -> Bool
    var pollsConnection = true

    @State private var copiedCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    introduction
                    codeCard
                    instructions
                    waitingStatus
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .mvScreenBackground()
            .navigationTitle("Connect caregiver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.mvAccent)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            guard pollsConnection else { return }
            await pollForConnection()
        }
    }

    private var introduction: some View {
        VStack(spacing: 12) {
            MVIconTile(systemImage: "message.fill", tint: .mvAccent, size: 64)
            Text("Connect through LINE")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.mvInk)
            Text("Ask your caregiver to complete these steps in LINE.")
                .font(.body)
                .foregroundStyle(Color.mvSubtle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var codeCard: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 13) {
                Text("Invite code")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mvSubtle)

                Text(verbatim: invite.code)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Color.mvInk)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .textSelection(.enabled)
                    .accessibilityLabel("Invite code")
                    .accessibilityValue(Text(verbatim: invite.code))

                if context.date < invite.expiresAt {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .accessibilityHidden(true)
                        Text("Expires in")
                        Text(timerInterval: context.date...invite.expiresAt, countsDown: true)
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.mvWarning)
                } else {
                    Label("Invite code expired", systemImage: "clock.badge.exclamationmark.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.mvDanger)
                }

                Button {
                    UIPasteboard.general.string = invite.code
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        copiedCode = true
                    }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copiedCode = false
                    }
                } label: {
                    Label(
                        copiedCode ? "Code copied" : "Copy code",
                        systemImage: copiedCode ? "checkmark" : "doc.on.doc"
                    )
                }
                .buttonStyle(MVSecondaryButtonStyle(tint: copiedCode ? .mvSuccess : .mvAccent))
                .disabled(context.date >= invite.expiresAt)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .glassCard(selected: true)
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            MVSectionHeader(title: "On your caregiver’s phone")
            VStack(spacing: 0) {
                instructionRow(number: 1, textKey: "Open the MedVision LINE Official Account.")
                Divider().overlay(Color.mvBorder.opacity(0.45)).padding(.leading, 48)
                instructionRow(number: 2, textKey: "Send the invite code above as a LINE message.")
                Divider().overlay(Color.mvBorder.opacity(0.45)).padding(.leading, 48)
                instructionRow(number: 3, textKey: "Keep this screen open until the connection is confirmed.")
            }
            .padding(.horizontal, 15)
            .glassCard()
        }
    }

    private var waitingStatus: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if context.date < invite.expiresAt {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.mvAccent)
                    Text("Waiting for your caregiver…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mvSubtle)
                }
            } else {
                Label(
                    "Close this screen and generate a new invite code.",
                    systemImage: "arrow.clockwise.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mvDanger)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func instructionRow(number: Int, textKey: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.mvOnAccent)
                .frame(width: 30, height: 30)
                .background(Color.mvAccent, in: Circle())
                .accessibilityHidden(true)

            Text(LocalizedStringKey(textKey))
                .font(.body)
                .foregroundStyle(Color.mvInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text(
                verbatim: AppLanguage.localized(
                    "step_accessibility_format",
                    locale: locale,
                    arguments: [
                        number,
                        AppLanguage.localized(textKey, locale: locale)
                    ]
                )
            )
        )
    }

    private func pollForConnection() async {
        while !Task.isCancelled, Date() < invite.expiresAt {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            if await checkConnection() {
                dismiss()
                return
            }
        }
    }
}

#Preview("Caregiver alerts — unlinked") {
    ScrollView {
        CaregiverAlertsCard(previewState: .unlinked)
            .padding(20)
    }
    .mvScreenBackground()
    .environment(AuthService())
}

#Preview("Caregiver alerts — linked, Thai dark") {
    ScrollView {
        CaregiverAlertsCard(previewState: .linked)
            .padding(20)
    }
    .mvScreenBackground()
    .environment(AuthService())
    .environment(\.locale, Locale(identifier: "th"))
    .preferredColorScheme(.dark)
}

#Preview("Caregiver alerts — loading, large text") {
    ScrollView {
        CaregiverAlertsCard(previewState: .loading)
            .padding(20)
    }
    .mvScreenBackground()
    .environment(AuthService())
    .dynamicTypeSize(.accessibility2)
}

#Preview("Caregiver alerts — guest") {
    ScrollView {
        CaregiverAlertsCard(previewState: .unlinked, availability: .guest)
            .padding(20)
    }
    .mvScreenBackground()
    .environment(AuthService())
}

#Preview("Caregiver alerts — unavailable") {
    ScrollView {
        CaregiverAlertsCard(previewState: .error, availability: .unavailable)
            .padding(20)
    }
    .mvScreenBackground()
    .environment(AuthService())
}

#Preview("Caregiver alerts — request error") {
    ScrollView {
        CaregiverAlertsCard(previewState: .error)
            .padding(20)
    }
    .mvScreenBackground()
    .environment(AuthService())
}

#Preview("Caregiver invite — Thai") {
    CaregiverInviteSheet(
        invite: CaregiverInvitePresentation(
            code: "MV7K9Q2X",
            expiresAt: Date().addingTimeInterval(15 * 60)
        ),
        checkConnection: { false },
        pollsConnection: false
    )
    .environment(\.locale, Locale(identifier: "th"))
}
