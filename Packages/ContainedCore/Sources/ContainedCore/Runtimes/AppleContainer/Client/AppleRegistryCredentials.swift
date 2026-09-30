import Foundation
import Security
import LocalAuthentication

enum AppleRegistryCredentials {
    static func lookup(_ host: String) throws -> Core.Registry.RegistryCredentials? {
        let server = host
        let authentication = LAContext()
        authentication.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrSecurityDomain as String: "com.apple.container.registry",
            kSecAttrServer as String: server,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: authentication,
        ]
        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)
        if result == errSecItemNotFound { return nil }
        // Background checks must not prompt or leak Keychain details into diagnostics.
        guard result == errSecSuccess,
              let attributes = item as? [String: Any],
              let account = attributes[kSecAttrAccount as String] as? String,
              let data = attributes[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw Core.Registry.ManifestError.tokenUnavailable
        }
        return Core.Registry.RegistryCredentials(username: account, password: password)
    }
}
