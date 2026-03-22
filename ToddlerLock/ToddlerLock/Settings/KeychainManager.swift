import Foundation
import Security

/// Manages password storage in the macOS Keychain.
/// Passwords are stored encrypted — never as plaintext in UserDefaults.
enum KeychainManager {
    private static let service = "com.toddlerlock.app"
    private static let account = "lockPassword"

    /// Save a password to the Keychain.
    static func savePassword(_ password: String) {
        guard let data = password.data(using: .utf8) else { return }

        // Delete any existing password first
        deletePassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[KeychainManager] Failed to save password: \(status)")
        }
    }

    /// Retrieve the password from the Keychain.
    static func loadPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Check if a given password matches the stored one.
    /// Uses constant-time comparison to prevent timing attacks.
    static func verifyPassword(_ input: String) -> Bool {
        guard let stored = loadPassword() else { return false }
        guard input.count == stored.count else { return false }

        // Constant-time comparison
        var match = true
        for (a, b) in zip(input.utf8, stored.utf8) {
            if a != b { match = false }
        }
        return match
    }

    /// Delete the stored password.
    static func deletePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Whether a password is currently stored.
    static var hasPassword: Bool {
        loadPassword() != nil
    }
}
