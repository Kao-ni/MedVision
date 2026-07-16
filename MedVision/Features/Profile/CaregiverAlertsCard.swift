import SwiftUI

/// Profile section: link a caregiver LINE account for missed-dose alerts.
struct CaregiverAlertsCard: View {
    @Environment(AuthService.self) private var auth

    @State private var isLinked = false
    @State private var inviteCode: String?
    @State private var instructions: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isBusy = false

    private var canUseCloud: Bool {
        !auth.isGuest && auth.session?.accessToken != nil && SupabaseConfig.isConfigured
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Caregiver LINE alerts")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "If a dose is not taken within 30 minutes, your linked caregiver gets one LINE message (medicine name and time only — not photos)."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if auth.isGuest {
                    Text("Sign in to enable caregiver LINE alerts. Guest mode stays on this device only.")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else if !SupabaseConfig.isConfigured {
                    Text("Supabase is not configured.")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                } else {
                    HStack {
                        Label(
                            isLinked ? "Caregiver connected" : "No caregiver linked",
                            systemImage: isLinked ? "checkmark.circle.fill" : "link"
                        )
                        .font(.subheadline)
                        .foregroundStyle(isLinked ? .green : .secondary)
                        Spacer()
                    }

                    if let inviteCode {
                        Text(inviteCode)
                            .font(.title)
                            .fontWeight(.bold)
                            .fontDesign(.monospaced)
                            .textSelection(.enabled)
                        if let instructions {
                            Text(instructions)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 10) {
                        Button {
                            Task { await generateInvite() }
                        } label: {
                            Text(isLinked ? "Replace caregiver" : "Generate invite code")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy || !canUseCloud)

                        if isLinked {
                            Button(role: .destructive) {
                                Task { await unlink() }
                            } label: {
                                Text("Unlink")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)
        }
        .task { await refreshStatus() }
    }

    private func refreshStatus() async {
        guard canUseCloud, let token = auth.session?.accessToken else { return }
        do {
            let status = try await CaregiverAlertService.fetchStatus(accessToken: token)
            isLinked = status.linked
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateInvite() async {
        guard let token = auth.session?.accessToken else { return }
        isBusy = true
        errorMessage = nil
        statusMessage = nil
        defer { isBusy = false }
        do {
            let invite = try await CaregiverAlertService.createInvite(accessToken: token)
            inviteCode = invite.code
            instructions = invite.instructions
            statusMessage = "Show this code to your caregiver. It expires in 15 minutes."
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unlink() async {
        guard let token = auth.session?.accessToken else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await CaregiverAlertService.unlink(accessToken: token)
            isLinked = false
            inviteCode = nil
            statusMessage = "Caregiver unlinked. Alerts stopped."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
