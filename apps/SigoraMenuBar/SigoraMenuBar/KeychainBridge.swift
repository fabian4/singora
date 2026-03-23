import Foundation
import Security

struct CredentialRecord: Identifiable, Equatable {
    let id: String
    let provider: String
    let credentialType: String
    let alias: String
    let updatedAt: Date
}

@MainActor
final class KeychainBridge: ObservableObject {
    @Published private(set) var credentials: [CredentialRecord] = []

    func importCredential(
        provider: String,
        credentialType: String,
        alias: String,
        secret: String
    ) throws {
        let account = accountKey(provider: provider, credentialType: credentialType, alias: alias)
        let data = Data(secret.utf8)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainBridgeError.osStatus(status)
        }

        try refresh()
    }

    func resolveSecret(
        provider: String,
        credentialType: String,
        alias: String
    ) throws -> String {
        let account = accountKey(provider: provider, credentialType: credentialType, alias: alias)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw KeychainBridgeError.osStatus(status)
        }

        guard
            let data = item as? Data,
            let secret = String(data: data, encoding: .utf8)
        else {
            throw KeychainBridgeError.invalidData
        }

        return secret
    }

    func refresh() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            credentials = []
            return
        }

        guard status == errSecSuccess else {
            throw KeychainBridgeError.osStatus(status)
        }

        let rows = (item as? [[String: Any]]) ?? []
        credentials = rows.compactMap { row in
            guard
                let account = row[kSecAttrAccount as String] as? String
            else {
                return nil
            }

            let parts = account.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }

            return CredentialRecord(
                id: account,
                provider: parts[0],
                credentialType: parts[1],
                alias: parts[2],
                updatedAt: row[kSecAttrModificationDate as String] as? Date ?? Date.distantPast
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func accountKey(provider: String, credentialType: String, alias: String) -> String {
        "\(provider)|\(credentialType)|\(alias)"
    }

    private let serviceName = "com.sigora.credentials"
}

enum KeychainBridgeError: LocalizedError {
    case osStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .osStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            return "Keychain operation failed: \(message)"
        case .invalidData:
            return "Stored credential data could not be decoded."
        }
    }
}
