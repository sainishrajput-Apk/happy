import Foundation
import Security

/// Thread-safe service for storing and retrieving sensitive credentials in the macOS Keychain.
public final class KeychainManager: @unchecked Sendable {
    public static let shared = KeychainManager()

    public let serviceName: String

    public init(serviceName: String = "com.happy.mac.credentials") {
        self.serviceName = serviceName
    }

    /// Saves or updates a string value for a given key.
    @discardableResult
    public func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Clean out any existing item first to ensure fresh attributes
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves a string value for a given key.
    public func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Deletes the item for a given key.
    @discardableResult
    public func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Deletes all items associated with this service name. Useful for test cleanup.
    @discardableResult
    public func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        var status = SecItemDelete(query as CFDictionary)
        while status == errSecSuccess {
            status = SecItemDelete(query as CFDictionary)
        }
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
