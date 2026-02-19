import Foundation
import Security

enum KeychainService {
    private static let service = "com.anyrouter.manager"
    private static let storeKey = "all_cookies"

    // In-memory cache to avoid repeated Keychain access
    private static var cache: [String: String]?

    static func save(cookie: String, for accountID: UUID) throws {
        var store = loadStore()
        store[accountID.uuidString] = cookie
        try saveStore(store)
    }

    static func load(for accountID: UUID) -> String? {
        let store = loadStore()
        return store[accountID.uuidString]
    }

    static func delete(for accountID: UUID) {
        var store = loadStore()
        store.removeValue(forKey: accountID.uuidString)
        try? saveStore(store)
    }

    // MARK: - Single-entry store

    private static func loadStore() -> [String: String] {
        if let c = cache { return c }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: storeKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            // Migrate old per-account entries if they exist
            let migrated = migrateOldEntries()
            cache = migrated
            return migrated
        }
        cache = dict
        return dict
    }

    private static func saveStore(_ store: [String: String]) throws {
        guard let data = try? JSONEncoder().encode(store) else { return }
        cache = store

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: storeKey,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: storeKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Migration from old per-account entries

    private static func migrateOldEntries() -> [String: String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [:] }

        var store: [String: String] = [:]
        for item in items {
            guard let key = item[kSecAttrAccount as String] as? String,
                  key != storeKey,
                  let data = item[kSecValueData as String] as? Data,
                  let value = String(data: data, encoding: .utf8) else { continue }
            store[key] = value

            // Delete old entry
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }

        if !store.isEmpty {
            try? saveStore(store)
        }
        return store
    }

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        var errorDescription: String? {
            switch self {
            case .saveFailed(let s): "Keychain save failed: \(s)"
            }
        }
    }
}
