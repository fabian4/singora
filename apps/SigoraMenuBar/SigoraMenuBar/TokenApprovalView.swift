import SwiftUI

struct TokenApprovalView: View {
    let approval: PendingApproval
    let approve: () async -> Void
    let deny: () async -> Void
    let details: TokenApprovalDetails
    @State private var auditNote = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ApprovalHeader(
                title: "Token Approval",
                subtitle: approval.summary,
                riskLevel: approval.riskLevel
            )

            SigoraGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    detailRow("Provider", details.provider)
                    detailRow("Action", details.action)
                    detailRow("Resource", details.resource)
                    detailRow("Credential Type", details.credentialType)
                    detailRow("Alias", details.alias)
                    detailRow("Requesting Client", details.requestingClient)
                    detailRow("Resource Context", details.resourceContext)
                }
            }

            SigoraGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    SigoraSectionTitle(title: "Policy Decision")
                    Text(details.policySummary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SigoraGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    SigoraSectionTitle(title: "Audit Note")
                    TextField(details.auditPlaceholder, text: $auditNote, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                        .padding(12)
                        .background(SigoraPalette.surface(for: colorScheme).opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            }
        }
        .padding(18)
        .frame(width: 620)
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
