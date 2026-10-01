import Foundation
import Security

protocol SessionStoring {
    func load() -> (token: String, user: AppUser)?
    func save(token: String, user: AppUser)
    func clear()
}

final class KeychainSessionStore: SessionStoring {
    private let service = "com.andresmorales.SmartParking"
    private let tokenAccount = "authToken"
    private let userKey = "currentUser"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> (token: String, user: AppUser)? {
        guard
            let token = readToken(),
            let data = defaults.data(forKey: userKey),
            let user = try? JSONDecoder().decode(AppUser.self, from: data)
        else { return nil }
        return (token, user)
    }

    func save(token: String, user: AppUser) {
        SecItemDelete(tokenQuery as CFDictionary)
        var query = tokenQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
        defaults.set(try? JSONEncoder().encode(user), forKey: userKey)
    }

    func clear() {
        SecItemDelete(tokenQuery as CFDictionary)
        defaults.removeObject(forKey: userKey)
    }

    private var tokenQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]
    }

    private func readToken() -> String? {
        var query = tokenQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
