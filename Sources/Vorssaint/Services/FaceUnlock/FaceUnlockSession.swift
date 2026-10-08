// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation
import CoreGraphics

/// Notifications only trigger a check. The session server is the authority.
enum FaceUnlockSession {
    static var isLockedForCurrentUser: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return accepts(session, userID: getuid())
    }

    static func accepts(_ session: [String: Any], userID: uid_t) -> Bool {
        session["CGSSessionScreenIsLocked"] as? Bool == true
            && session[kCGSessionOnConsoleKey as String] as? Bool == true
            && (session[kCGSessionUserIDKey as String] as? NSNumber)?.uint32Value == userID
    }
}
