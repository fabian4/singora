import SwiftUI

struct RuntimePanelView: View {
    @StateObject private var viewModel = RuntimePanelViewModel()
    @State private var selection: PanelSheet?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SigoraPalette.danger)
            }

            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Refreshing runtime state…")
                        .font(.system(size: 12))
                        .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
                }
            } else if viewModel.approvals.isEmpty {
                emptyState
            } else {
                approvalsList
            }

            quickActions
            recentActivity
            footer
        }
        .padding(14)
        .frame(width: 320)
        .background(SigoraPalette.background(for: colorScheme))
        .sigoraPanelBackground()
        .task {
            await viewModel.refresh()
        }
        .sheet(item: $selection) { sheet in
            switch sheet {
            case .pair(let approval):
                if let details = approval.pairDetails {
                    PairApprovalView(
                        approval: approval,
                        approve: { await viewModel.decide(approvalId: approval.id, approved: true) },
                        deny: { await viewModel.decide(approvalId: approval.id, approved: false) },
                        details: details
                    )
                    .presentationBackground(.clear)
                }
            case .token(let approval):
                if let details = approval.tokenDetails {
                    TokenApprovalView(
                        approval: approval,
                        approve: { await viewModel.decide(approvalId: approval.id, approved: true) },
                        deny: { await viewModel.decide(approvalId: approval.id, approved: false) },
                        details: details
                    )
                    .presentationBackground(.clear)
                }
            case .importCredential:
                CredentialImportView()
                    .presentationBackground(.clear)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sigora Runtime")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                HStack(spacing: 6) {
                    Circle()
                        .fill(SigoraPalette.success)
                        .frame(width: 7, height: 7)
                    Text("Healthy")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SigoraPalette.success)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(SigoraPalette.primary)
        }
    }

    private var approvalsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SigoraSectionTitle(title: "Needs Attention")
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.approvals) { approval in
                        approvalRow(approval)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private func approvalRow(_ approval: PendingApproval) -> some View {
        SigoraGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(approval.requestKind == .pair ? "Pair Request" : "Token Request")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                        Text(approval.summary)
                            .font(.system(size: 12))
                            .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    RiskBadge(level: approval.riskLevel)
                }

                HStack(spacing: 8) {
                    Button("Approve") {
                        Task { await viewModel.decide(approvalId: approval.id, approved: true) }
                    }
                    .buttonStyle(SigoraPrimaryButtonStyle())

                    Button("Deny") {
                        Task { await viewModel.decide(approvalId: approval.id, approved: false) }
                    }
                    .buttonStyle(SigoraGhostButtonStyle())

                    Spacer()

                    Button("Details") {
                        selection = approval.requestKind == .pair ? .pair(approval) : .token(approval)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(SigoraPalette.primary)
                    .font(.system(size: 12, weight: .medium))
                }
            }
        }
    }

    private var emptyState: some View {
        SigoraGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                SigoraSectionTitle(title: "Needs Attention")
                Text("No pending approvals")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
                Text("Start `sigorad-server` and run `sigora pair` to see requests appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SigoraSectionTitle(title: "Quick Actions")
            HStack(spacing: 10) {
                quickAction("Pause", systemImage: "pause.circle")
                quickAction("Refresh", systemImage: "arrow.triangle.2.circlepath")
                quickAction("Import", systemImage: "square.and.arrow.down") {
                    selection = .importCredential
                }
            }
        }
    }

    private func quickAction(_ title: String, systemImage: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(SigoraPalette.surface(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SigoraPalette.outline(for: colorScheme), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(SigoraPalette.textPrimary(for: colorScheme))
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            SigoraSectionTitle(title: "Recent Activity")
            VStack(alignment: .leading, spacing: 10) {
                activityRow("Successful login: Admin")
                activityRow("Security policy updated")
                activityRow("Runtime heartbeat: OK")
            }
        }
    }

    private func activityRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(SigoraPalette.primary)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Button("Open Full Dashboard") {}
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SigoraPalette.primary)

            Spacer()

            Button("Settings") {}
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SigoraPalette.textSecondary(for: colorScheme))
        }
    }
}

enum PanelSheet: Identifiable {
    case pair(PendingApproval)
    case token(PendingApproval)
    case importCredential

    var id: String {
        switch self {
        case .pair(let approval):
            return "pair-\(approval.id)"
        case .token(let approval):
            return "token-\(approval.id)"
        case .importCredential:
            return "import"
        }
    }
}
