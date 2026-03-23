import Foundation

@MainActor
final class RuntimePanelViewModel: ObservableObject {
    @Published private(set) var approvals: [PendingApproval] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastAuthenticatedAt: Date?

    private let client: RuntimeAPIClient
    private let authenticator: LocalAuthenticationService

    init(
        client: RuntimeAPIClient = RuntimeAPIClient(),
        authenticator: LocalAuthenticationService = LocalAuthenticationService()
    ) {
        self.client = client
        self.authenticator = authenticator
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            approvals = try await client.fetchPendingApprovals()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func decide(approvalId: UUID, approved: Bool) async {
        do {
            let authenticatedAt: Date?
            if approved {
                let reason = "Approve a Sigora runtime request."
                authenticatedAt = try await authenticator.authenticate(reason: reason)
                lastAuthenticatedAt = authenticatedAt
            } else {
                authenticatedAt = nil
            }

            try await client.submitDecision(
                ApprovalDecisionRequest(
                    approvalId: approvalId,
                    approved: approved,
                    note: nil
                    ,
                    authenticatedAt: authenticatedAt
                )
            )
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RuntimeAPIClient {
    private let baseURL = URL(string: "http://127.0.0.1:8611")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func fetchPendingApprovals() async throws -> [PendingApproval] {
        let url = baseURL.appending(path: "/ui/pending")
        let (data, response) = try await session.data(from: url)
        try validate(response: response)
        return try SigoraWireAdapter.pendingApprovals(from: data, decoder: decoder)
    }

    func submitDecision(_ decision: ApprovalDecisionRequest) async throws {
        let url = baseURL.appending(path: "/ui/decision")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(decision)

        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw RuntimeAPIError.invalidResponse
        }
    }
}

enum RuntimeAPIError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The Sigora runtime returned an invalid response."
        }
    }
}
