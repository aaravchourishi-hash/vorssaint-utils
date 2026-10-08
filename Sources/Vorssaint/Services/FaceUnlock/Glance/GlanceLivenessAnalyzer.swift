// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlanceLivenessAnalyzer.swift
//  glance
//
//  Rolling-window driver for the liveness cues. Takes `GlanceLivenessFrame`, not
//  `GlanceFaceRecognitionResult`, keeping this file's dependency graph shallow enough
//  to compile standalone in `tools/liveness_selftest.swift`.
//

import Foundation

@MainActor
final class GlanceLivenessAnalyzer {
    private let windowDuration: TimeInterval

    /// Read fresh on every `observe()`, not captured at init, so a mid-scan Settings change takes effect immediately.
    var modeProvider: () -> GlanceLivenessMode = { .light }
    var tuningProvider: () -> GlanceLivenessTuning = { .default }
    /// Face Lab can switch individual cues off to isolate one; the unlock
    /// path leaves this at "all enabled."
    var enabledCuesProvider: () -> Set<GlanceLivenessCue> = { Set(GlanceLivenessCue.allCases) }

    private var frames: [GlanceLivenessFrame] = []
    private var evaluator = GlanceLivenessEvaluator()
    private(set) var lastSnapshot = GlanceLivenessSnapshot.empty
    /// Kept for Face Lab's diagnostics panel (excess ratio, coherence, pair
    /// counts, yaw range) — the numbers behind the flat-vs-3D cue's level.
    private(set) var lastGeometry = GlanceGeometryLivenessResult.empty

    init(windowDuration: TimeInterval = 2.0) {
        self.windowDuration = windowDuration
    }

    func reset() {
        frames.removeAll()
        evaluator.reset()
        lastSnapshot = .empty
        lastGeometry = .empty
    }

    /// Call once per frame with a detected face, regardless of whether it matched an identity,
    /// so liveness stays an independent gate. The window is time-pruned (~2s) but the evaluator's
    /// fire counts are not — they accumulate across the whole scan, so a spoof tell can't be waited out.
    @discardableResult
    func observe(_ frame: GlanceLivenessFrame) -> GlanceLivenessSnapshot {
        frames.append(frame)
        frames.removeAll { frame.timestamp.timeIntervalSince($0.timestamp) > windowDuration }

        evaluator.mode = modeProvider()
        evaluator.tuning = tuningProvider()
        evaluator.enabledCues = enabledCuesProvider()

        let geometry = GlanceGeometryLiveness.evaluate(frames)
        lastGeometry = geometry

        let readings = GlanceLivenessCues.readings(window: frames, geometry: geometry)
        let snapshot = evaluator.observe(readings)
        lastSnapshot = snapshot
        return snapshot
    }
}
