// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlanceKeychainManager.swift
//  glance
//
//  Thin, password-agnostic wrapper around Keychain Services — save/read/delete/exists by account, plus a Touch-ID access control helper.
//

import Foundation
import Security
import LocalAuthentication

enum GlanceKeychainError: LocalizedError {
    case itemNotFound
    case unexpectedData
    case accessControlFailed(String)
    case authenticationFailed
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain item not found."
        case .unexpectedData:
            return "Keychain item had an unexpected format."
        case .accessControlFailed(let msg):
            return "Couldn't create Keychain access control: \(msg)"
        case .authenticationFailed:
            return "Authentication was cancelled or failed."
        case .osStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain error: \(message)"
        }
    }
}

enum GlanceKeychainManager {
    enum Storage: Equatable {
        case loginKeychain, protectedKeychain

        /// An entitlement claim selects the protected path, which the OS then
        /// validates. An invalid claim fails; it never downgrades on error.
        static func select(entitlements: [String: Any]) -> Self {
            let groups = entitlements["keychain-access-groups"] as? [String] ?? []
            let appID = entitlements["com.apple.application-identifier"] as? String ?? ""
            return !appID.isEmpty || groups.contains(where: { !$0.isEmpty })
                ? .protectedKeychain : .loginKeychain
        }
    }

    nonisolated static let storage: Storage = {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var information: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let values = information as? [String: Any] else { return .loginKeychain }
        return Storage.select(entitlements: values[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:])
    }()

    // Local storage has a separate namespace. Changing signing never silently
    // re-wraps, overwrites or downgrades an existing protected session key.
    nonisolated static let storageSuffix = storage == .loginKeychain ? ".local-auth" : ""
    nonisolated static let service = (Bundle.main.bundleIdentifier ?? "com.vorssaint.face-unlock.tests") + ".face-unlock" + storageSuffix

    private static func query(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Older integration builds stored only the ACL-protected wrapping key
        // in the data-protection keychain. Preserve that exact split.
        if storage == .protectedKeychain, account == "sessionKey" {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    /// Attributes-only existence check — never prompts, even for access-controlled items.
    nonisolated static func exists(account: String) -> Bool {
        (try? contains(account: account)) ?? false
    }

    /// Authorization must distinguish absence from a Keychain failure. A
    /// failed lookup must never create a replacement for an existing key.
    nonisolated static func contains(account: String) throws -> Bool {
        var query = query(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess, errSecInteractionNotAllowed: return true
        case errSecItemNotFound: return false
        case let status: throw GlanceKeychainError.osStatus(status)
        }
    }

    /// Pass an `LAContext` to authorize a read on an access-controlled item — the OS presents the prompt during this call.
    nonisolated static func read(account: String, context: LAContext? = nil) throws -> Data {
        var query = query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        if let context {
            query[kSecUseAuthenticationContext as String] = context
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw GlanceKeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            throw GlanceKeychainError.itemNotFound
        case errSecUserCanceled, errSecAuthFailed:
            throw GlanceKeychainError.authenticationFailed
        default:
            throw GlanceKeychainError.osStatus(status)
        }
    }

    /// Stores an item, updating its data in place when it already exists. Updating
    /// avoids the delete/add gap that can race with a second submit and produce
    /// `errSecDuplicateItem`. Existing access-control attributes are preserved;
    /// this method's access-control argument applies when adding a new item.
    nonisolated static func save(account: String, data: Data, accessControl: SecAccessControl? = nil) throws {
        let itemQuery = query(account: account)

        let updateStatus = SecItemUpdate(
            itemQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            break // Add below.
        default:
            throw GlanceKeychainError.osStatus(updateStatus)
        }

        var addQuery = itemQuery
        addQuery[kSecValueData as String] = data
        if let accessControl {
            addQuery[kSecAttrAccessControl as String] = accessControl
        }
        // The file-based login Keychain uses app ACLs, not iOS accessibility
        // attributes. Adding SecAccessControl here would select the protected
        // keychain and fail with -34018 for local/ad-hoc builds.

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess { return }
        // Another save may have added the item after our update reported
        // not-found. Complete that competing replacement with an update instead
        // of surfacing an avoidable “item already exists” error.
        if status == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(
                itemQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard retryStatus == errSecSuccess else { throw GlanceKeychainError.osStatus(retryStatus) }
            return
        }
        throw GlanceKeychainError.osStatus(status)
    }

    nonisolated static func delete(account: String) throws {
        let query = query(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GlanceKeychainError.osStatus(status)
        }
    }

    /// `.userPresence` requires Touch ID or device password, with no separate no-hardware handling needed.
    nonisolated static func makeUserPresenceAccessControl() throws -> SecAccessControl {
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            &accessError
        ) else {
            let msg = (accessError?.takeRetainedValue() as Error?)?.localizedDescription ?? "unknown"
            throw GlanceKeychainError.accessControlFailed(msg)
        }
        return access
    }
}
