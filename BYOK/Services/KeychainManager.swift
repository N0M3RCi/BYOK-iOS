import Foundation
import Security

/// Thread-safe Keychain wrapper for storing auth tokens and sensitive data.
final class KeychainManager: @unchecked Sendable {
    static let shared = KeychainManager()

    private let tokenKey = "com.byok.auth.token"
    private let userIDKey = "com.byok.auth.userID"
    private let emailKey = "com.byok.auth.email"
    private let sessionIDKey = "com.byok.session.id"
    private let passcodeKey = "com.byok.auth.passcode"
    private let queue = DispatchQueue(label: "com.byok.keychain", qos: .userInitiated)

    private init() {}

    // MARK: - Save & Read

    func saveToken(_ token: String) {
        save(key: tokenKey, data: Data(token.utf8))
    }

    func getToken() -> String? {
        guard let data = read(key: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveUserID(_ id: String) {
        save(key: userIDKey, data: Data(id.utf8))
    }

    func getUserID() -> String? {
        guard let data = read(key: userIDKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveEmail(_ email: String) {
        save(key: emailKey, data: Data(email.utf8))
    }

    func getEmail() -> String? {
        guard let data = read(key: emailKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveSessionID(_ id: String) {
        save(key: sessionIDKey, data: Data(id.utf8))
    }

    func getSessionID() -> String? {
        guard let data = read(key: sessionIDKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func savePasscode(_ passcode: String) {
        save(key: passcodeKey, data: Data(passcode.utf8))
    }

    func getPasscode() -> String? {
        guard let data = read(key: passcodeKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func hasPasscode() -> Bool {
        getPasscode() != nil
    }

    func deletePasscode() {
        delete(key: passcodeKey)
    }

    // MARK: - Provider API Keys

    private func providerAPIKeyKey(_ id: Int) -> String { "com.byok.provider.\(id).api_key" }
    private func providerURLKey(_ id: Int) -> String { "com.byok.provider.\(id).api_url" }

    func saveProviderAPIKey(_ key: String, forProviderId id: Int) {
        save(key: providerAPIKeyKey(id), data: Data(key.utf8))
    }

    func getProviderAPIKey(forProviderId id: Int) -> String? {
        guard let data = read(key: providerAPIKeyKey(id)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveProviderURL(_ url: String, forProviderId id: Int) {
        save(key: providerURLKey(id), data: Data(url.utf8))
    }

    func getProviderURL(forProviderId id: Int) -> String? {
        guard let data = read(key: providerURLKey(id)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteProviderKeys(forProviderId id: Int) {
        delete(key: providerAPIKeyKey(id))
        delete(key: providerURLKey(id))
    }

    // MARK: - Clear All

    func clearAll() {
        queue.sync {
            [tokenKey, userIDKey, emailKey, sessionIDKey].forEach { key in
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key
                ]
                SecItemDelete(query as CFDictionary)
            }
        }
    }

    // MARK: - Private

    private func save(key: String, data: Data) {
        queue.sync {
            // Delete existing
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            // Add new
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func read(key: String) -> Data? {
        queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return status == errSecSuccess ? result as? Data : nil
        }
    }

    private func delete(key: String) {
        queue.sync {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}