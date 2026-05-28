import Foundation
import Security

enum KeychainService {
    static let service = Bundle.main.bundleIdentifier ?? "com.MAP-89.Colligere"
    static let anthropicKeyAccount = "anthropic_api_key"

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? {
            switch self { case .saveFailed(let s): "Keychain save failed: \(s)" }
        }
    }

    static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]
        var status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
