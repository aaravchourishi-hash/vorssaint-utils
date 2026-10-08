// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum FaceUnlockIndicatorPhase: Equatable {
    case scanning, submitting, failed

    var symbol: String {
        switch self {
        case .scanning: return "faceid"
        case .submitting: return "key.fill"
        case .failed: return "lock.fill"
        }
    }

    var message: FaceUnlockText {
        switch self {
        case .scanning: return .scanning
        case .submitting: return .submitted
        case .failed: return .timeout
        }
    }
}

enum FaceUnlockIndicatorRoute {
    case hidden, island, fallback

    static func resolve(active: Bool, locked: Bool, islandEnabled: Bool, islandVisible: Bool) -> Self {
        guard active, locked else { return .hidden }
        return islandEnabled && islandVisible ? .island : .fallback
    }
}

/// Pure gates shared by setup, the scanner and the final keystroke boundary.
enum FaceUnlockPolicy {
    static let matchThreshold: Float = 0.66
    static let scanDuration: TimeInterval = 10
    static let sampleCount = 5

    static func canScan(installed: Bool, enabled: Bool, consent: Bool,
                        sessionAuthorized: Bool, passwordSaved: Bool, faceEnrolled: Bool,
                        cameraGranted: Bool, accessibilityGranted: Bool,
                        locked: Bool, onConsole: Bool, sleeping: Bool, submitted: Bool) -> Bool {
        installed && enabled && consent && sessionAuthorized && passwordSaved && faceEnrolled
            && cameraGranted && accessibilityGranted && locked && onConsole && !sleeping && !submitted
    }

    static func matches(centroid: Float, sample: Float, modelMatches: Bool) -> Bool {
        modelMatches && centroid.isFinite && sample.isFinite
            && centroid >= matchThreshold && sample >= matchThreshold
    }

    static func acceptsPose(index: Int, yaw: Float?, pitch: Float?) -> Bool {
        guard let yaw, let pitch, yaw.isFinite, pitch.isFinite,
              abs(yaw) < 0.55, abs(pitch) < 0.4 else { return false }
        switch index {
        case 0: return abs(yaw) < 0.2 && abs(pitch) < 0.18
        case 1: return yaw > 0.2 && abs(pitch) < 0.2
        case 2: return yaw < -0.2 && abs(pitch) < 0.2
        case 3: return pitch < -0.15 && abs(yaw) < 0.2
        case 4: return pitch > 0.15 && abs(yaw) < 0.2
        default: return false
        }
    }

    /// A missing face, a different identity or a gap breaks the liveness chain.
    static func continuesTrack(previous: UUID?, current: UUID?, elapsed: TimeInterval) -> Bool {
        previous != nil && previous == current && elapsed >= 0 && elapsed < 0.5
    }
}

/// A revoked scan can never resume credential injection after an await.
final class FaceUnlockPermit: @unchecked Sendable {
    private let lock = NSLock()
    private var revoked = false
    func revoke() { lock.lock(); revoked = true; lock.unlock() }
    var isValid: Bool { lock.lock(); defer { lock.unlock() }; return !revoked }
}
