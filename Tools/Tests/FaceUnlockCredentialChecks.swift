// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []
    func record(_ value: String) { lock.lock(); entries.append(value); lock.unlock() }
    var values: [String] { lock.lock(); defer { lock.unlock() }; return entries }
}

@main
struct FaceUnlockCredentialChecks {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: message, code: 1) }
    }

    static func main() async throws {
        typealias Storage = GlanceKeychainManager.Storage
        try require(Storage.select(entitlements: [:]) == .loginKeychain, "local build must not require a provisioned entitlement")
        try require(Storage.select(entitlements: ["com.apple.application-identifier": "TEAM.example.app"]) == .protectedKeychain,
                    "App ID keeps the protected backend")
        try require(Storage.select(entitlements: ["keychain-access-groups": ["TEAM.example.app"]]) == .protectedKeychain,
                    "access-group builds keep the protected backend")
        try require(Storage.select(entitlements: ["keychain-access-groups": [String]()]) == .loginKeychain, "empty claims are not an access group")
        try require(Storage.select(entitlements: ["com.apple.security.device.camera": true]) == .loginKeychain, "camera entitlement does not grant Keychain access")

        let log = Recorder()
        let value = try await FaceUnlockAuthorization.perform(permit: FaceUnlockPermit(), authenticate: {
            log.record("authenticated")
        }, load: { log.record("read key"); return 42 })
        try require(value == 42 && log.values == ["authenticated", "read key"], "authentication must precede every session-key read")

        let rejected = Recorder()
        do {
            _ = try await FaceUnlockAuthorization.perform(permit: FaceUnlockPermit(), authenticate: {
                throw CancellationError()
            }, load: { rejected.record("read key"); return 0 })
            throw NSError(domain: "cancelled authentication succeeded", code: 1)
        } catch is CancellationError {}
        try require(rejected.values.isEmpty, "cancelled or failed authentication must not read or create a key")

        let cancelled = FaceUnlockPermit()
        let stale = Recorder()
        do {
            _ = try await FaceUnlockAuthorization.perform(permit: cancelled, authenticate: { cancelled.revoke() },
                                                          load: { stale.record("read key"); return 0 })
            throw NSError(domain: "revoked authorization succeeded", code: 1)
        } catch is CancellationError {}
        try require(stale.values.isEmpty, "pausing during authentication must block storage access")

        let revokeWhileReading = FaceUnlockPermit()
        do {
            _ = try await FaceUnlockAuthorization.perform(permit: revokeWhileReading, authenticate: {}, load: {
                revokeWhileReading.revoke()
                return 42
            })
            throw NSError(domain: "stale key was returned", code: 1)
        } catch is CancellationError {}
        print("AUTHORIZATION CHECKS OK")

        // Exercise the actual signing/storage boundary with disposable bytes,
        // never an existing credential, face template or authentication prompt.
        try require(GlanceKeychainManager.storage == .loginKeychain, "this test executable must be locally signed")
        let account = "diagnostic-" + UUID().uuidString
        let bytes = Data("non-secret-test-data".utf8)
        try require(try !GlanceKeychainManager.contains(account: account), "new diagnostic account must be absent")
        try GlanceKeychainManager.save(account: account, data: bytes)
        defer { try? GlanceKeychainManager.delete(account: account) }
        try require(try GlanceKeychainManager.contains(account: account), "saved diagnostic account must exist")
        try require(try GlanceKeychainManager.read(account: account) == bytes, "local Keychain roundtrip")
        let replacement = Data("replacement-test-data".utf8)
        try GlanceKeychainManager.save(account: account, data: replacement)
        try require(try GlanceKeychainManager.read(account: account) == replacement, "Keychain update must preserve the item")
        try GlanceKeychainManager.delete(account: account)
        try require(try !GlanceKeychainManager.contains(account: account), "diagnostic item must be removed")
        print("LOCAL KEYCHAIN ROUNDTRIP OK")
    }
}
