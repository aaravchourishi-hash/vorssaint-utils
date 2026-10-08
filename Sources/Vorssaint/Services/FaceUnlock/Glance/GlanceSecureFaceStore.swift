// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.

import Foundation

/// Encrypted templates live in Vorssaint's own owner-only container, never Glance's.
enum GlanceSecureFaceStore {
    private static var fileURL: URL {
        get throws {
            guard let container = PrivateFileStore.containerURL else {
                throw CocoaError(.fileNoSuchFile)
            }
            return container.appendingPathComponent("FaceUnlock\(GlanceKeychainManager.storageSuffix)/face-identities.enc")
        }
    }

    static var exists: Bool {
        guard let url = try? fileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func load() throws -> [GlanceFaceIdentity] {
        guard GlanceSecureCredentialManager.isSessionUnlocked else {
            throw GlanceSecureCredentialError.sessionLocked
        }
        let url = try fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        // A read failure is not an empty enrollment. Never overwrite an unreadable store.
        let ciphertext = try Data(contentsOf: url)
        var plaintext = try GlanceSecureCredentialManager.decrypt(ciphertext)
        defer { plaintext.resetBytes(in: 0..<plaintext.count) }
        return try JSONDecoder().decode([GlanceFaceIdentity].self, from: plaintext)
    }

    static func save(_ identities: [GlanceFaceIdentity]) throws {
        let url = try fileURL
        var plaintext = try JSONEncoder().encode(identities)
        defer { plaintext.resetBytes(in: 0..<plaintext.count) }
        let ciphertext = try GlanceSecureCredentialManager.encrypt(plaintext)
        guard PrivateFileStore.createDirectory(at: url.deletingLastPathComponent()),
              PrivateFileStore.write(ciphertext, to: url) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    static func deleteAll() throws {
        let url = try fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
