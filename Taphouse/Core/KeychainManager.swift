import Foundation
import Security

/// Manages secure storage in the macOS Keychain for trial persistence
enum KeychainManager {
    private static let service = "com.multimodalsolutions.taphouse"
    private static let trialStartKey = "trialStartDate"

    /// Stores the trial start date in the Keychain
    @discardableResult
    static func storeTrialStartDate(_ date: Date) -> Bool {
        let timestamp = date.timeIntervalSince1970
        guard let data = "\(timestamp)".data(using: .utf8) else { return false }

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: trialStartKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: trialStartKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieves the trial start date from the Keychain
    static func getTrialStartDate() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: trialStartKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let timestampString = String(data: data, encoding: .utf8),
              let timestamp = Double(timestampString) else {
            return nil
        }

        return Date(timeIntervalSince1970: timestamp)
    }

    /// Checks if a trial start date exists in the Keychain
    static func hasTrialStartDate() -> Bool {
        return getTrialStartDate() != nil
    }

    /// Removes the trial start date from the Keychain
    @discardableResult
    static func removeTrialStartDate() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: trialStartKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
