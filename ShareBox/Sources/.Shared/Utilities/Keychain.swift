//
//  Keychain.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import Foundation
import Security

class Keychain {
    static var shared = Keychain()

    // Add in-memory cache to reduce keychain access
    private var tokenCache: [String: String] = [:]

    // Add access control for better keychain permissions
    private let accessControl: SecAccessControl = {
        let flags: SecAccessControlCreateFlags = [.privateKeyUsage]
        return SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlocked,
            flags,
            nil
        )!
    }()

    func saveToken(_ token: String, key: String) {
        tokenCache[key] = token

        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrSynchronizable as String: false
        ]
        // Remove old item if exists
        SecItemDelete(query as CFDictionary)
        // Save new key
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            NotificationCenter.default.post(name: .keychainItemChanged, object: nil, userInfo: ["key": key, "action": "save"])
        }
    }

    func deleteToken(key: String) {
        tokenCache.removeValue(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            NotificationCenter.default.post(name: .keychainItemChanged, object: nil, userInfo: ["key": key, "action": "delete"])
        }
    }

    func fetchToken(key: String) -> String? {
        // Check cache first
        if let cachedToken = tokenCache[key] {
            return cachedToken
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
