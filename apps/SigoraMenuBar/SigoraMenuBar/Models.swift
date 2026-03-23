import Foundation

enum ApprovalKind: String, Codable {
    case pair
    case token
}

enum RiskLevel: String, Codable {
    case low
    case medium
    case high
}

struct PendingApproval: Codable, Identifiable {
    let id: UUID
    let requestKind: ApprovalKind
    let summary: String
    let riskLevel: RiskLevel
    let createdAt: Date
    let pairDetails: PairApprovalDetails?
    let tokenDetails: TokenApprovalDetails?
}

struct ApprovalDecisionRequest: Codable {
    let approvalId: UUID
    let approved: Bool
    let note: String?
    let authenticatedAt: Date?
}

struct PairApprovalDetails: Codable {
    let clientName: String
    let clientId: String
    let deviceName: String?
    let userHint: String?
    let fingerprint: String
    let origin: String
    let ttl: String
    let countdown: String
}

struct TokenApprovalDetails: Codable {
    let provider: String
    let action: String
    let resource: String
    let credentialType: String
    let alias: String
    let requestingClient: String
    let resourceContext: String
    let policySummary: String
    let auditPlaceholder: String
}

struct CredentialImportDraft {
    var provider: String = "github"
    var credentialType: String = "bearer_token"
    var alias: String = "work"
    var secret: String = ""
    var aliasValid: Bool = true
    var willOverwrite: Bool = false
}

private struct PendingApprovalWire: Codable {
    let id: UUID
    let request_kind: ApprovalKind
    let summary: String
    let risk_level: RiskLevel
    let created_at: Date
    let pair_details: PairApprovalDetails?
    let token_details: TokenApprovalDetails?

    var model: PendingApproval {
        PendingApproval(
            id: id,
            requestKind: request_kind,
            summary: summary,
            riskLevel: risk_level,
            createdAt: created_at,
            pairDetails: pair_details,
            tokenDetails: token_details
        )
    }
}

enum SigoraWireAdapter {
    static func pendingApprovals(from data: Data, decoder: JSONDecoder) throws -> [PendingApproval] {
        try decoder.decode([PendingApprovalWire].self, from: data).map(\.model)
    }
}
