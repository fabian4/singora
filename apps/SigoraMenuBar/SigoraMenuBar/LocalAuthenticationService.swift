import Foundation
import LocalAuthentication

@MainActor
final class LocalAuthenticationService: ObservableObject {
    func authenticate(reason: String) async throws -> Date {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        guard canEvaluate else {
            throw LocalAuthenticationError.unavailable(error?.localizedDescription)
        }

        let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        guard success else {
            throw LocalAuthenticationError.failed
        }

        return Date()
    }
}

enum LocalAuthenticationError: LocalizedError {
    case unavailable(String?)
    case failed

    var errorDescription: String? {
        switch self {
        case .unavailable(let details):
            if let details, !details.isEmpty {
                return "System authentication is unavailable: \(details)"
            }
            return "System authentication is unavailable on this device."
        case .failed:
            return "Authentication did not complete successfully."
        }
    }
}
