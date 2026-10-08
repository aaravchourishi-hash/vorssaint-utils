// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlanceLivenessCues.swift
//  glance
//
//  Liveness decision model: five independent cues, no combined score. DENY
//  cues override CONFIRM cues unconditionally; a confirm cue's absence is never a failure.
//

import CoreGraphics

/// One cue's latest reading. `confidence` 0 is always an abstention, never a reading of
/// zero — a cue that can't see anything must not be able to convict or acquit.
struct GlanceCueReading: Equatable {
    /// 0...1 strength of this cue's own evidence, in the direction that
    /// cue argues for (spoof-ness for deny cues, liveness for confirm cues).
    let level: Float
    let confidence: Float

    nonisolated static let none = GlanceCueReading(level: 0, confidence: 0)
}

enum GlanceLivenessCueRole: Equatable {
    /// Evidence of a spoof. Firing fails the scan and overrides confirmation.
    case deny
    /// Evidence of a real face. Firing passes the liveness half of the scan.
    case confirm
}

enum GlanceLivenessCue: String, CaseIterable, Hashable, Identifiable {
    case glossGlare
    case deviceDetected
    case flatVs3D
    case depthPose
    case blink

    var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .glossGlare: return "Gloss/glare"
        case .deviceDetected: return "Device detected"
        case .flatVs3D: return "Flat vs 3D"
        case .depthPose: return "Depth/pose"
        case .blink: return "Blink"
        }
    }

    nonisolated var role: GlanceLivenessCueRole {
        switch self {
        case .glossGlare, .deviceDetected: return .deny
        case .flatVs3D, .depthPose, .blink: return .confirm
        }
    }

    /// One-line explanation of what firing actually means, for Face Lab.
    nonisolated var explanation: String {
        switch self {
        case .glossGlare: return "Large flat specular highlight — glass/screen glare rather than skin's small scattered shine."
        case .deviceDetected: return "A device-shaped rectangle overlaps the face — a phone or tablet held up."
        case .flatVs3D: return "Held-out nose points miss the plane fit — the face has real depth."
        case .depthPose: return "Nose offset tracks head yaw — the nose sits off the eye plane, so this isn't flat."
        case .blink: return "Eye aspect ratio dipped and recovered — a photo cannot blink."
        }
    }
}

/// How much liveness checking runs. Both modes always run the deny cues —
/// the difference is only whether a *positive* proof of life is also
/// required before unlocking.
enum GlanceLivenessMode: String, CaseIterable, Identifiable, Sendable {
    /// Deny-only: "confirmed unless proven wrong." Never blocks a user who sits still — the default.
    case light
    /// Deny cues plus at least one confirm cue must fire. Can block a user who holds
    /// perfectly still and never blinks for the whole scan.
    case heavy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .heavy: return "Heavy"
        }
    }

    var summary: String {
        switch self {
        case .light: return "Only rejects obvious spoofs."
        case .heavy: return "Also requires proof of a real face."
        }
    }
}

/// Fire thresholds per cue: a cue counts a frame when its reading is confident and
/// at/above `level`, and fires once it has counted `frames` of them within the scan.
/// Seeded from real-device observation; retune from Face Lab.
struct GlanceLivenessTuning: Equatable {
    var glossLevel: Float = 0.04
    var glossFrames: Int = 3

    /// Deliberately lower than `glossLevel` — the device rectangle detector was already
    /// the one signal proven reliable in real-device testing.
    var deviceLevel: Float = 0.15
    var deviceFrames: Int = 3

    /// Not the 0.5 you might expect: real-world Vision jitter alone measures ~0.21-0.46
    /// in the self-test, so 0.5 would mean this cue essentially never fires.
    var flatVs3DLevel: Float = 0.25
    var flatVs3DFrames: Int = 2

    /// Deliberately high: this level is a remapped correlation `(r + 1) / 2`, so 0.5 is
    /// zero correlation (evidence of nothing) — 0.8 requires r >= 0.6.
    var depthPoseLevel: Float = 0.8
    var depthPoseFrames: Int = 2

    /// A blink is already a discrete dip-and-recover event (see `GlanceLivenessScoring.blinkDynamics`),
    /// not a ramping level, so one firing frame is the event itself.
    var blinkFrames: Int = 1

    /// Frames Light mode waits before auto-confirming, so deny cues get a fair chance to
    /// fire first — otherwise a first-frame match could unlock before glare/device ever ran.
    var lightModeMinimumFrames: Int = 3

    nonisolated static let `default` = GlanceLivenessTuning()

    nonisolated func level(for cue: GlanceLivenessCue) -> Float {
        switch cue {
        case .glossGlare: return glossLevel
        case .deviceDetected: return deviceLevel
        case .flatVs3D: return flatVs3DLevel
        case .depthPose: return depthPoseLevel
        // Any confident blink reading is the event; see `blinkFrames`.
        case .blink: return 0.5
        }
    }

    nonisolated func frames(for cue: GlanceLivenessCue) -> Int {
        switch cue {
        case .glossGlare: return glossFrames
        case .deviceDetected: return deviceFrames
        case .flatVs3D: return flatVs3DFrames
        case .depthPose: return depthPoseFrames
        case .blink: return blinkFrames
        }
    }
}

enum GlanceLivenessDecision: Equatable {
    /// Nothing decided yet. Not a failure — the scan should keep going.
    case pending
    /// Cue is `nil` when Light mode auto-confirmed rather than any cue firing.
    case confirmed(by: GlanceLivenessCue?)
    case denied(by: GlanceLivenessCue)

    var isConfirmed: Bool { if case .confirmed = self { return true }; return false }
    var isDenied: Bool { if case .denied = self { return true }; return false }

    /// User-facing explanation for a denial, matching the tone of the
    /// coordinator's other outcome strings.
    var denialReason: String? {
        guard case .denied(let cue) = self else { return nil }
        switch cue {
        case .glossGlare: return "Screen glare detected — this looks like a photo on a display."
        case .deviceDetected: return "A device-shaped rectangle was detected around the face — this looks like a photo or screen."
        default: return "Liveness check failed."
        }
    }
}

/// Running state for one cue across a scan.
struct GlanceLivenessCueState: Equatable {
    var reading: GlanceCueReading = .none
    /// Cumulative, not consecutive — forgiving of one-frame dropouts Vision produces mid-scan.
    var framesCounted: Int = 0
    var hasFired: Bool = false

    /// 0...1 progress toward firing, for Face Lab's progress bars.
    func progress(threshold: Int) -> Float {
        guard threshold > 0 else { return hasFired ? 1 : 0 }
        return min(1, Float(framesCounted) / Float(threshold))
    }
}

struct GlanceLivenessSnapshot: Equatable {
    let decision: GlanceLivenessDecision
    let mode: GlanceLivenessMode
    let cueStates: [GlanceLivenessCue: GlanceLivenessCueState]
    let frameCount: Int

    nonisolated static let empty = GlanceLivenessSnapshot(
        decision: .pending, mode: .light, cueStates: [:], frameCount: 0
    )

    func state(for cue: GlanceLivenessCue) -> GlanceLivenessCueState {
        cueStates[cue] ?? GlanceLivenessCueState()
    }
}

/// The stateful decision core, kept as a plain `struct` rather than folded
/// into `GlanceLivenessAnalyzer` so `tools/liveness_selftest.swift` can drive the
/// real firing/latching logic frame by frame with no actor or camera.
struct GlanceLivenessEvaluator {
    var mode: GlanceLivenessMode
    var tuning: GlanceLivenessTuning
    /// Face Lab can switch individual cues off to isolate one; the unlock
    /// path leaves this at "all enabled."
    var enabledCues: Set<GlanceLivenessCue>

    private(set) var states: [GlanceLivenessCue: GlanceLivenessCueState] = [:]
    private(set) var framesObserved: Int = 0

    init(
        mode: GlanceLivenessMode = .light,
        tuning: GlanceLivenessTuning = .default,
        enabledCues: Set<GlanceLivenessCue> = Set(GlanceLivenessCue.allCases)
    ) {
        self.mode = mode
        self.tuning = tuning
        self.enabledCues = enabledCues
    }

    mutating func reset() {
        states = [:]
        framesObserved = 0
    }

    /// Firing is latched: a cue that has fired stays fired for the rest of the scan.
    mutating func observe(_ readings: [GlanceLivenessCue: GlanceCueReading]) -> GlanceLivenessSnapshot {
        framesObserved += 1

        for cue in GlanceLivenessCue.allCases {
            var state = states[cue] ?? GlanceLivenessCueState()
            let reading = readings[cue] ?? .none
            state.reading = reading
            if reading.confidence > 0, reading.level >= tuning.level(for: cue) {
                state.framesCounted += 1
                if state.framesCounted >= tuning.frames(for: cue) {
                    state.hasFired = true
                }
            }
            states[cue] = state
        }

        return GlanceLivenessSnapshot(
            decision: currentDecision(), mode: mode, cueStates: states, frameCount: framesObserved
        )
    }

    /// Deny is evaluated first and is unconditional — it overrides any confirmation already reached.
    private func currentDecision() -> GlanceLivenessDecision {
        for cue in GlanceLivenessCue.allCases
        where cue.role == .deny && enabledCues.contains(cue) && (states[cue]?.hasFired ?? false) {
            return .denied(by: cue)
        }

        if mode == .light {
            return framesObserved >= tuning.lightModeMinimumFrames ? .confirmed(by: nil) : .pending
        }

        for cue in GlanceLivenessCue.allCases
        where cue.role == .confirm && enabledCues.contains(cue) && (states[cue]?.hasFired ?? false) {
            return .confirmed(by: cue)
        }

        return .pending
    }
}

/// Turns a rolling window into this frame's reading for every cue. Deny cues read only
/// the latest frame (per-frame appearance); confirm cues read the whole window (cross-frame motion).
enum GlanceLivenessCues {
    nonisolated static func readings(
        window: [GlanceLivenessFrame], geometry: GlanceGeometryLivenessResult
    ) -> [GlanceLivenessCue: GlanceCueReading] {
        [
            .glossGlare: glossGlare(window.last),
            .deviceDetected: deviceDetected(window.last),
            .flatVs3D: geometry.planarReading,
            .depthPose: GlanceLivenessScoring.poseDepthConsistency(window),
            .blink: GlanceLivenessScoring.blinkDynamics(window),
        ]
    }

    /// Skin gives many small scattered specular points; glass gives one big
    /// flat blob. `specularFraction` alone would fire on a bright forehead,
    /// so it's gated by how concentrated that glare is.
    nonisolated static func glossGlare(_ frame: GlanceLivenessFrame?) -> GlanceCueReading {
        guard let glare = frame?.glare else { return .none }
        let fractionScore = ramp(glare.specularFraction, floor: 0.01, ceiling: 0.08)
        let clusterFactor = ramp(glare.specularClusterRatio, floor: 0.3, ceiling: 1.0)
        let level = fractionScore * (0.3 + 0.7 * clusterFactor)
        // Below ~50 native px of face there isn't enough detail to tell a
        // glare blob from a bright patch; ramps to full trust by ~130px.
        let confidence = ramp(Float(glare.cropPixelWidth), floor: 50, ceiling: 130)
        return GlanceCueReading(level: level, confidence: confidence)
    }

    /// Raw overlap fraction from `GlanceDeviceBezelDetector`, used directly rather than re-scaled.
    nonisolated static func deviceDetected(_ frame: GlanceLivenessFrame?) -> GlanceCueReading {
        guard let overlap = frame?.deviceOverlapFraction else { return .none }
        return GlanceCueReading(level: Float(min(max(overlap, 0), 1)), confidence: 1)
    }

    nonisolated static func ramp(_ value: Float, floor: Float, ceiling: Float) -> Float {
        min(max((value - floor) / max(ceiling - floor, 0.0001), 0), 1)
    }
}
