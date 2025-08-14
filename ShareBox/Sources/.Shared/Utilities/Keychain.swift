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

    func saveToken(_ token: String, key: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
//            kSecAttrAccessGroup as String: "group.com.thom1606.ShareBox",
            kSecValueData as String: data
        ]
        // Remove old item if exists
        SecItemDelete(query as CFDictionary)
        // Save new key
        SecItemAdd(query as CFDictionary, nil)
    }

    func deleteToken(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
//            kSecAttrAccessGroup as String: "group.com.thom1606.ShareBox"
        ]
        SecItemDelete(query as CFDictionary)
    }

    func fetchToken(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
//            kSecAttrAccessGroup as String: "group.com.thom1606.ShareBox",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
