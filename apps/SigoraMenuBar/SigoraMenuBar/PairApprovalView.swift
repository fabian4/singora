import SwiftUI

struct PairApprovalView: View {
    let approval: PendingApproval
    let approve: () async -> Void
    let deny: () async -> Void
    let details: PairApprovalDetails
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ApprovalHeader(
                title: "Pair Approval",
                subtitle: approval.summary,
                riskLevel: approval.riskLevel
            )

            SigoraGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    detailRow("Client Name", details.clientName)
                    detailRow("Client ID", details.clientId)
                    detailRow("Device Name", details.deviceName ?? "Unknown")
                    detailRow("User Hint", details.userHint ?? "None")
                }
            }

            SigoraGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    SigoraSectionTitle(title: "Fingerprint")
                    Text(details.fingerprint)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                        .textSelection(.enabled)

                    Divider().overlay(SigoraPalette.outline(for: colorScheme))

                    detailRow("Request Origin", details.origin)
                }
            }

            HStack(spacing: 14) {
                SigoraGlassCard {
                    detailRow("Session TTL", details.ttl)
                }

                SigoraGlassCard {
                    detailRow("Timeout", details.countdown)
                }
            }

            HStack(spacing: 10) {
                Button("Approve") {
                    Task { await approve() }
                }
                .buttonStyle(SigoraPrimaryButtonStyle())

                Button("Deny") {
                    Task { await deny() }
                }
                .buttonStyle(SigoraGhostButtonStyle())

                Spacer()
            }
        }
        .padding(18)
        .frame(width: 560)
        .background(SigoraPalette.background(for: colorScheme))
        .sigoraPanelBackground()
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SigoraSectionTitle(title: label)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
