import Foundation
import Security

enum KeychainService {
    private static let service = "com.anyrouter.manager"
    private static var caches: [StoreKind: [String: String]] = [:]

    private enum StoreKind: String, CaseIterable {
        case cookies = "all_cookies"
        case apiKeys = "all_api_keys"

        var backupFileName: String {
            switch self {
            case .cookies: "cookies.json"
            case .apiKeys: "api-keys.json"
            }
        }
    }

    static func save(cookie: String, for accountID: UUID) throws {
        var store = loadStore(.cookies)
        store[accountID.uuidString] = cookie
        try saveStore(store, kind: .cookies)
    }

    static func load(for accountID: UUID) -> String? {
        let store = loadStore(.cookies)
        return store[accountID.uuidString]
    }

    static func delete(for accountID: UUID) {
        var store = loadStore(.cookies)
        store.removeValue(forKey: accountID.uuidString)
        try? saveStore(store, kind: .cookies)
    }

    static func saveAPIKey(_ apiKey: String, for accountID: UUID) throws {
        var store = loadStore(.apiKeys)
        store[accountID.uuidString] = apiKey
        try saveStore(store, kind: .apiKeys)
    }

    static func loadAPIKey(for accountID: UUID) -> String? {
        let store = loadStore(.apiKeys)
        return store[accountID.uuidString]
    }

    static func deleteAPIKey(for accountID: UUID) {
        var store = loadStore(.apiKeys)
        store.removeValue(forKey: accountID.uuidString)
        try? saveStore(store, kind: .apiKeys)
    }

    // MARK: - Single-entry store

    private static func loadStore(_ kind: StoreKind) -> [String: String] {
        if let cache = caches[kind] { return cache }

        if let dict = loadKeychainStore(kind: kind) {
            caches[kind] = dict
            try? saveBackupStore(dict, kind: kind)
            return dict
        }

        if let dict = loadBackupStore(kind: kind) {
            caches[kind] = dict
            try? saveKeychainStore(dict, kind: kind)
            return dict
        }

        // Migrate old per-account cookie entries if they exist.
        guard kind == .cookies else {
            caches[kind] = [:]
            return [:]
        }

        let migrated = migrateOldEntries()
        caches[kind] = migrated
        if !migrated.isEmpty {
            try? saveBackupStore(migrated, kind: kind)
        }
        return migrated
    }

    private static func loadKeychainStore(kind: StoreKind) -> [String: String]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return dict
    }

    private static func saveStore(_ store: [String: String], kind: StoreKind) throws {
        caches[kind] = store

        var lastError: Error?

        do {
            try saveKeychainStore(store, kind: kind)
        } catch {
            lastError = error
        }

        do {
            try saveBackupStore(store, kind: kind)
            lastError = nil
        } catch {
            if lastError == nil {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
    }

    private static func saveKeychainStore(_ store: [String: String], kind: StoreKind) throws {
        guard let data = try? JSONEncoder().encode(store) else { return }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: kind.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func loadBackupStore(kind: StoreKind) -> [String: String]? {
        guard let url = backupURL(for: kind),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return nil
        }
        return dict
    }

    @discardableResult
    private static func saveBackupStore(_ store: [String: String], kind: StoreKind) throws -> URL {
        guard let url = backupURL(for: kind) else {
            throw BackupStoreError.unavailable
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(store)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }

    private static func backupURL(for kind: StoreKind) -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return appSupport
            .appendingPathComponent(service, isDirectory: true)
            .appendingPathComponent(kind.backupFileName, isDirectory: false)
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
                  !StoreKind.allCases.map(\.rawValue).contains(key),
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
            try? saveStore(store, kind: .cookies)
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

    enum BackupStoreError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable: "Backup cookie store unavailable"
            }
        }
    }
}
import Foundation

enum BalanceCacheService {
    struct Entry: Codable {
        let quota: Double
        let usedQuota: Double
        let lastRefreshAt: Date?
        let lastCheckInAt: Date?
    }

    private static let fileName = "balance-cache.json"
    private static var cache: [String: Entry]?

    static func load(for accountID: UUID) -> Entry? {
        let store = loadStore()
        return store[accountID.uuidString]
    }

    static func save(quota: Double, usedQuota: Double, lastRefreshAt: Date?, lastCheckInAt: Date?, for accountID: UUID) {
        var store = loadStore()
        store[accountID.uuidString] = Entry(
            quota: quota,
            usedQuota: usedQuota,
            lastRefreshAt: lastRefreshAt,
            lastCheckInAt: lastCheckInAt
        )
        saveStore(store)
    }

    static func updateCheckInDate(_ date: Date?, for accountID: UUID) {
        var store = loadStore()
        let existing = store[accountID.uuidString] ?? Entry(quota: 0, usedQuota: 0, lastRefreshAt: nil, lastCheckInAt: nil)
        store[accountID.uuidString] = Entry(
            quota: existing.quota,
            usedQuota: existing.usedQuota,
            lastRefreshAt: existing.lastRefreshAt,
            lastCheckInAt: date
        )
        saveStore(store)
    }

    static func delete(for accountID: UUID) {
        var store = loadStore()
        store.removeValue(forKey: accountID.uuidString)
        saveStore(store)
    }

    private static func loadStore() -> [String: Entry] {
        if let cache { return cache }
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            cache = [:]
            return [:]
        }
        cache = store
        return store
    }

    private static func saveStore(_ store: [String: Entry]) {
        cache = store
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(store)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
        }
    }

    private static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("com.anyrouter.manager", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
