import Foundation
import Security

/// Persists the Lumen session cookies in the macOS Keychain.
///
/// Cookies are stored as a JSON-encoded array of a small Codable struct under a
/// generic-password item. No passwords are ever stored — only the session cookie
/// that Lumen sets after a successful CILogon login.
private struct StoredCookie: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let secure: Bool
    let expires: Date?
}

enum KeychainStore {
    private static let service = "lumen.ncsa.illinois.edu"
    private static let account = "LumenCoins.session-cookies"

    static func save(cookies: [HTTPCookie]) {
        let stored = cookies.map {
            StoredCookie(name: $0.name, value: $0.value, domain: $0.domain,
                         path: $0.path, secure: $0.isSecure, expires: $0.expiresDate)
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)  // replace any existing item
        var add = base
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> [HTTPCookie] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let stored = try? JSONDecoder().decode([StoredCookie].self, from: data) else {
            return []
        }
        return stored.compactMap { s -> HTTPCookie? in
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: s.name,
                .value: s.value,
                .domain: s.domain,
                .path: s.path,
                .secure: s.secure
            ]
            if let exp = s.expires { props[.expires] = exp }
            return HTTPCookie(properties: props)
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
