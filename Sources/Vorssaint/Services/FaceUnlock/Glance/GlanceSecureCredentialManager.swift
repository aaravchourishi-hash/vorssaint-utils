// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlanceSecureCredentialManager.swift
//  glance
//
//  An authenticated session key wraps the password and face templates.
//  Provisioned builds use Keychain user presence; local builds explicitly
//  authenticate with macOS before reading their separate login-Keychain key.
//

import Foundation
import CryptoKit
import LocalAuthentication

enum GlanceSecureCredentialError: LocalizedError {
    case emptyPassword
    case sessionLocked
    case encryptionFailed
    case decryptionFailed
    case sessionKeyUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyPassword:
            return "Password cannot be empty."
        case .sessionLocked:
            return "Session is locked. Authenticate with Touch ID before storing or using the password."
        case .encryptionFailed:
            return "Encryption failed."
        case .decryptionFailed:
            return "Decryption failed. The stored credential may be corrupted."
        case .sessionKeyUnavailable:
            return "The session key is missing, but encrypted data still exists that only it could read. Nothing has been deleted. Use “Forget face and password” in Face Unlock settings to clear both and start fresh."
        }
    }
}

extension Notification.Name {
    /// Fires whenever the cached session key changes, so anything encrypted under it (e.g. `GlanceFaceEnrollmentStore`) can reload
    /// itself instead of relying on each call site to remember to — a past bug had the sidebar's unlock forget this, leaving
    /// face unlock silently running on stale pre-unlock data.
    static let secureCredentialSessionDidChange = Notification.Name("GlanceSecureCredentialManager.sessionDidChange")
}

enum GlanceSecureCredentialManager {
    nonisolated private static let sessionKeyAccount = "sessionKey"
    nonisolated private static let passwordBlobAccount = "encryptedPassword"

    // MARK: - Session state (thread-safe via NSLock)

    nonisolated private static let sessionLock = NSLock()
    nonisolated(unsafe) private static var _cachedKey: SymmetricKey?
    /// Last unlock or successful `readPassword` — what `SessionAutoLocker` compares against the idle limit. Guarded by
    /// `sessionLock` alongside the key so the two can never be observed out of step.
    nonisolated(unsafe) private static var _lastActivityAt: Date?

    nonisolated static var isSessionUnlocked: Bool {
        sessionLock.lock(); defer { sessionLock.unlock() }
        return _cachedKey != nil
    }

    /// `nil` whenever the session is locked — there is no activity to age.
    nonisolated static var lastActivityAt: Date? {
        sessionLock.lock(); defer { sessionLock.unlock() }
        return _lastActivityAt
    }

    nonisolated private static func cachedKey() -> SymmetricKey? {
        sessionLock.lock(); defer { sessionLock.unlock() }
        return _cachedKey
    }

    nonisolated private static func setCachedKey(_ key: SymmetricKey?, permit: FaceUnlockPermit? = nil) {
        sessionLock.lock()
        if let permit, !permit.isValid { sessionLock.unlock(); return }
        let changed = (key != nil) != (_cachedKey != nil)
        _cachedKey = key
        _lastActivityAt = key == nil ? nil : Date()
        sessionLock.unlock()
        // Posted after releasing the lock — observers may call back into `isSessionUnlocked` (re-acquiring it) from a
        // background thread, so posting while still locked risks a real self-deadlock, not a theoretical one.
        guard changed else { return }
        NotificationCenter.default.post(name: .secureCredentialSessionDidChange, object: nil)
    }

    /// Resets the idle countdown on each successful use, so an actively-used session never auto-locks.
    nonisolated private static func recordActivity() {
        sessionLock.lock()
        if _cachedKey != nil { _lastActivityAt = Date() }
        sessionLock.unlock()
    }

    // MARK: - Generic session-key crypto (shared by passwords here and face embeddings in GlanceSecureFaceStore; requires an unlocked session)

    nonisolated static func encrypt(_ plaintext: Data) throws -> Data {
        guard let key = cachedKey() else { throw GlanceSecureCredentialError.sessionLocked }
        do {
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else { throw GlanceSecureCredentialError.encryptionFailed }
            return combined
        } catch {
            throw GlanceSecureCredentialError.encryptionFailed
        }
    }

    nonisolated static func decrypt(_ ciphertext: Data) throws -> Data {
        guard let key = cachedKey() else { throw GlanceSecureCredentialError.sessionLocked }
        do {
            let sealed = try AES.GCM.SealedBox(combined: ciphertext)
            return try AES.GCM.open(sealed, using: key)
        } catch {
            throw GlanceSecureCredentialError.decryptionFailed
        }
    }

    // MARK: - Public API

    nonisolated static func hasStoredPassword() -> Bool {
        GlanceKeychainManager.exists(account: passwordBlobAccount)
    }

    /// Never block an executor waiting for LocalAuthentication's callback.
    /// Local builds use application-gated authentication plus the login
    /// Keychain's app ACL; provisioned builds retain OS-enforced key access.
    nonisolated static func unlockSession(reason: String, permit: FaceUnlockPermit) async throws {
        guard permit.isValid, !Task.isCancelled else { throw CancellationError() }
        if cachedKey() != nil { return }
        let context = LAContext()
        context.localizedReason = reason
        var data = try await withTaskCancellationHandler {
            try await FaceUnlockAuthorization.perform(permit: permit, authenticate: {
                if GlanceKeychainManager.storage == .loginKeychain {
                    guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) else {
                        throw GlanceKeychainError.authenticationFailed
                    }
                }
            }, load: {
                try loadOrCreateSessionKey(context: context, permit: permit)
            })
        } onCancel: {
            context.invalidate()
        }
        defer { data.resetBytes(in: 0..<data.count) }
        setCachedKey(SymmetricKey(data: data), permit: permit)
    }

    private nonisolated static func loadOrCreateSessionKey(context: LAContext, permit: FaceUnlockPermit) throws -> Data {
        let protected = GlanceKeychainManager.storage == .protectedKeychain
        // An attributes-only check determines absence. A failed or cancelled
        // read never causes a new key to replace an existing one.
        if try GlanceKeychainManager.contains(account: sessionKeyAccount) {
            return try GlanceKeychainManager.read(account: sessionKeyAccount, context: protected ? context : nil)
        }
        guard try !GlanceKeychainManager.contains(account: passwordBlobAccount), !GlanceSecureFaceStore.exists else {
            throw GlanceSecureCredentialError.sessionKeyUnavailable
        }
        guard permit.isValid else { throw CancellationError() }
        let key = SymmetricKey(size: .bits256)
        var bytes = key.withUnsafeBytes { Data($0) }
        defer { bytes.resetBytes(in: 0..<bytes.count) }
        let access = protected ? try GlanceKeychainManager.makeUserPresenceAccessControl() : nil
        try GlanceKeychainManager.save(account: sessionKeyAccount, data: bytes, accessControl: access)
        // A protected add alone does not establish user presence; read it back
        // through the gated path before caching. Local authentication already
        // succeeded before this function was allowed to create or read a key.
        return try GlanceKeychainManager.read(account: sessionKeyAccount, context: protected ? context : nil)
    }

    /// Checked without needing the key itself, so this stays answerable precisely when the key can't be read.
    nonisolated static var hasSessionEncryptedData: Bool {
        GlanceKeychainManager.exists(account: passwordBlobAccount) || GlanceSecureFaceStore.exists
    }

    /// Clears the cached session key. Next save/read requires Touch ID again.
    nonisolated static func lockSession() {
        setCachedKey(nil)
    }

    /// Encrypts and stores `passwordBytes`. Requires an unlocked session —
    /// call `unlockSession(reason:)` first. Blocking; call from a background task.
    nonisolated static func savePassword(_ passwordBytes: Data, permit: FaceUnlockPermit) throws {
        guard !passwordBytes.isEmpty else { throw GlanceSecureCredentialError.emptyPassword }
        let combined = try encrypt(passwordBytes)
        sessionLock.lock()
        defer { sessionLock.unlock() }
        guard permit.isValid, _cachedKey != nil else { throw CancellationError() }
        try GlanceKeychainManager.save(account: passwordBlobAccount, data: combined)
    }

    /// No separate Touch ID prompt — only the session key was gated, at unlock time. Caller MUST zero the returned bytes via
    /// `.resetBytes(in:)` after use. Blocking; call from a background task.
    nonisolated static func readPassword() throws -> Data {
        guard cachedKey() != nil else { throw GlanceSecureCredentialError.sessionLocked }
        let ciphertext = try GlanceKeychainManager.read(account: passwordBlobAccount)
        let plaintext = try decrypt(ciphertext)
        // Only on success: a failed read shouldn't extend the idle window.
        recordActivity()
        return plaintext
    }

    /// Deletes both Keychain items and clears the cached session key.
    nonisolated static func deletePassword() throws {
        try GlanceKeychainManager.delete(account: passwordBlobAccount)
        try GlanceKeychainManager.delete(account: sessionKeyAccount)
        setCachedKey(nil)
    }
}
