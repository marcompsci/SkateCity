// KeychainManager.swift
// SkateCity — Secure storage using the iOS Keychain.
// Replaces UserDefaults for any data that should be protected from
// device backup inspection, Keychain dumping on jailbroken devices
// is blocked by kSecAttrAccessibleWhenUnlockedThisDeviceOnly.
//
// Copyright © 2026 MAR / SkateCity. All rights reserved.

import Foundation
import Security

final class KeychainManager {

    static let shared = KeychainManager()
    private let service = "com.skatecity.app"
    private init() {}

    // MARK: - Write

    @discardableResult
    func set(_ value: Data, forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecValueData:        value,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func set(_ string: String, forKey key: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return set(data, forKey: key)
    }

    @discardableResult
    func set<T: Encodable>(_ value: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return set(data, forKey: key)
    }

    // MARK: - Read

    func data(forKey key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    func string(forKey key: String) -> String? {
        guard let data = data(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func value<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Delete

    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    func deleteAll() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Secure UserDefaults wrapper

/// Drop-in replacements for UserDefaults that store values in the Keychain instead.
extension KeychainManager {

    static let bestScoreKey      = "skatecity.bestScore"
    static let wardrobeKey       = "skaterWardrobeProfile"
    static let onboardingKey     = "onboardingComplete"
    static let playerIDKey       = "skatecity.playerID"

    var bestScore: Int {
        get { value(Int.self, forKey: Self.bestScoreKey) ?? 0 }
        set { set(newValue, forKey: Self.bestScoreKey) }
    }

    var onboardingComplete: Bool {
        get { value(Bool.self, forKey: Self.onboardingKey) ?? false }
        set { set(newValue, forKey: Self.onboardingKey) }
    }

    var wardrobeProfile: SkaterWardrobeProfile? {
        get { value(SkaterWardrobeProfile.self, forKey: Self.wardrobeKey) }
        set {
            if let v = newValue { set(v, forKey: Self.wardrobeKey) }
            else { delete(forKey: Self.wardrobeKey) }
        }
    }

    /// Stable anonymous player ID — generated once, stored in Keychain.
    var playerID: String {
        if let id = string(forKey: Self.playerIDKey) { return id }
        let id = UUID().uuidString
        set(id, forKey: Self.playerIDKey)
        return id
    }
}
