// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlanceFaceEmbedder.swift
//  glance
//
//  Two implementations: `GlanceVisionFeaturePrintEmbedder` (Apple's built-in, but only ~5-7% similarity gap between people —
//  too thin to gate unlock on) and `GlanceArcFaceEmbedder` (real face-discriminative model).
//

import Foundation
import CoreGraphics

/// `nonisolated` so implementations can run on a background task despite the project's default main-actor isolation.
protocol GlanceFaceEmbedder: Sendable {
    /// Name shown in the debug UI so it's obvious which embedder produced a given saved sample.
    nonisolated var name: String { get }
    /// Persisted alongside every sample; `GlanceSecureFaceStore` uses it to refuse comparing across different embedders
    /// (which wouldn't error, just produce confident nonsense).
    nonisolated var modelIdentifier: String { get }
    /// Declared output length, for cross-model mismatch detection without running an embedding first.
    nonisolated var embeddingDimension: Int { get }
    /// Whether this embedder needs a canonically-aligned input (ArcFace) vs. tolerating a loose crop (Vision feature-print).
    nonisolated var requiresAlignment: Bool { get }
    nonisolated func embedding(for face: CGImage) throws -> [Float]
}

enum GlanceFaceEmbedding {
    /// Scales `vector` to unit length; matters once vectors are combined (see `average` below).
    static func l2Normalized(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(Float(0)) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }

    /// Cosine similarity, range -1...1. The raw value ArcFace thresholds are quoted in (typical cutoffs ~0.28-0.40).
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }

    /// For the legacy Vision-feature-print UI only. Don't use to tune ArcFace thresholds — use `cosineSimilarity` directly.
    static func similarityPercent(_ a: [Float], _ b: [Float]) -> Double {
        let similarity = cosineSimilarity(a, b)
        return Double((similarity + 1) / 2) * 100
    }

    /// Normalize each sample, average, then renormalize — a plain element-wise mean would let a larger-magnitude
    /// sample silently dominate.
    static func average(_ vectors: [[Float]]) -> [Float]? {
        guard let first = vectors.first, !first.isEmpty else { return nil }
        let count = Float(vectors.count)
        var sum = [Float](repeating: 0, count: first.count)
        for vector in vectors where vector.count == first.count {
            let normalized = l2Normalized(vector)
            for i in 0..<normalized.count { sum[i] += normalized[i] }
        }
        let mean = sum.map { $0 / count }
        return l2Normalized(mean)
    }
}
