// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A revoked operation can never cache a session key or inject credentials.
final class FaceUnlockPermit: @unchecked Sendable {
    private let lock = NSLock()
    private var revoked = false
    func revoke() { lock.lock(); revoked = true; lock.unlock() }
    var isValid: Bool { lock.lock(); defer { lock.unlock() }; return !revoked }
}

/// Local-build session keys are only read/created after macOS authentication.
/// Kept at the credential boundary, so UI changes cannot skip authentication.
enum FaceUnlockAuthorization {
    static func perform<Value: Sendable>(
        permit: FaceUnlockPermit,
        authenticate: @Sendable () async throws -> Void,
        load: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        guard permit.isValid, !Task.isCancelled else { throw CancellationError() }
        try await authenticate()
        guard permit.isValid, !Task.isCancelled else { throw CancellationError() }
        let value = try await Task.detached {
            guard permit.isValid else { throw CancellationError() }
            return try load()
        }.value
        guard permit.isValid, !Task.isCancelled else { throw CancellationError() }
        return value
    }
}
