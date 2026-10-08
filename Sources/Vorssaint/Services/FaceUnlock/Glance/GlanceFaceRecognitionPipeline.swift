// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlanceFaceRecognitionPipeline.swift
//  glance
//
//  Only place that should construct a GlanceFaceEmbedder — keeps all consumers in sync.
//

import Foundation
import CoreGraphics
import Observation

struct GlanceFaceRecognitionResult {
    let embedding: [Float]
    /// What was actually fed to the embedder, for debug UIs to inspect.
    let alignedImage: CGImage
    let alignmentTier: GlanceAlignmentTier
    let quality: Float?
    let face: GlanceDetectedFace
}

enum GlanceFaceRecognitionPipelineError: LocalizedError {
    case noFaceDetected
    case alignmentFailed

    var errorDescription: String? {
        switch self {
        case .noFaceDetected: return "No face detected in frame."
        case .alignmentFailed: return "Could not align the detected face."
        }
    }
}

/// `@Observable` so the debug UI can surface which embedder is active.
@Observable
@MainActor
final class GlanceFaceRecognitionPipeline {
    nonisolated let embedder: GlanceFaceEmbedder

    /// Never substitute a generic image feature print for a face recognition model.
    init(embedder: GlanceFaceEmbedder) {
        self.embedder = embedder
    }

    /// `nonisolated` so callers can run detect/align/embed from a background task instead of blocking the main actor.
    /// - Parameter previousBoundingBox: previous frame's selected box, if any — lets a continuous scanner keep selection "stuck" to the same person instead of re-picking every frame.
    nonisolated func recognize(in frame: CGImage, preferNear previousBoundingBox: CGRect? = nil) throws -> GlanceFaceRecognitionResult {
        let faces = try GlanceFaceDetector.detectFaces(in: frame)
        guard let face = Self.selectDominantFace(in: faces, preferNear: previousBoundingBox) else {
            throw GlanceFaceRecognitionPipelineError.noFaceDetected
        }
        return try recognize(face, in: frame)
    }

    /// Aligns and embeds an already-chosen face; enrollment uses this to bypass the prominence filter so a too-small face reads as "move closer" rather than "nobody there".
    nonisolated func recognize(_ face: GlanceDetectedFace, in frame: CGImage) throws -> GlanceFaceRecognitionResult {
        let inputImage: CGImage
        let tier: GlanceAlignmentTier
        if embedder.requiresAlignment {
            guard let aligned = GlanceFaceAligner.align(face, from: frame) else {
                throw GlanceFaceRecognitionPipelineError.alignmentFailed
            }
            inputImage = aligned.image
            tier = aligned.tier
        } else {
            guard let cropped = GlanceFaceDetector.crop(face, from: frame) else {
                throw GlanceFaceRecognitionPipelineError.alignmentFailed
            }
            inputImage = cropped
            tier = .paddedCrop
        }

        let embedding = try embedder.embedding(for: inputImage)
        return GlanceFaceRecognitionResult(embedding: embedding, alignedImage: inputImage, alignmentTier: tier, quality: face.quality, face: face)
    }

    /// Largest face by area with no prominence cutoff — unlike `selectDominantFace`, so enrollment can tell "too far" apart from "no face".
    nonisolated static func largestFace(in faces: [GlanceDetectedFace]) -> GlanceDetectedFace? {
        faces.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }
    }

    /// Below this fraction of frame width, a face is treated as a bystander, not a candidate — shared with onboarding's "move closer" prompt. `nonisolated(unsafe)` because it's read from a background-task static func that can't touch GlanceSettings' MainActor-isolated storage.
    nonisolated(unsafe) static var minimumProminentFaceWidth: Float = 0.18

    /// Max normalized-coordinate drift between frames still counted as "the same person".
    nonisolated private static let continuityDistanceTolerance: CGFloat = 0.3

    /// Picks the person actually at the camera, not a bystander: filters out faces below `minimumProminentFaceWidth`, then prefers continuity with `previousBoundingBox` over raw largest-by-area so two similarly-sized faces can't flip-flop the selection frame to frame and starve the liveness/wrong-face streaks of agreement.
    nonisolated static func selectDominantFace(in faces: [GlanceDetectedFace], preferNear previousBoundingBox: CGRect? = nil) -> GlanceDetectedFace? {
        let candidates = faces.filter { $0.normalizedBoundingBox.width >= CGFloat(minimumProminentFaceWidth) }
        guard !candidates.isEmpty else { return nil }

        if let previous = previousBoundingBox {
            let previousCenter = CGPoint(x: previous.midX, y: previous.midY)
            if let nearest = candidates.min(by: { distance(from: $0, to: previousCenter) < distance(from: $1, to: previousCenter) }),
               distance(from: nearest, to: previousCenter) < continuityDistanceTolerance {
                return nearest
            }
        }

        return candidates.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }
    }

    nonisolated private static func distance(from face: GlanceDetectedFace, to point: CGPoint) -> CGFloat {
        let center = CGPoint(x: face.normalizedBoundingBox.midX, y: face.normalizedBoundingBox.midY)
        return hypot(center.x - point.x, center.y - point.y)
    }
}

struct GlanceScoredIdentity {
    let identity: GlanceFaceIdentity
    /// Similarity against the identity's averaged template.
    let centroidSimilarity: Float
    /// Similarity against the single closest individual sample — catches
    /// cases where averaging blurred together poses that shouldn't be
    /// blended.
    let maxSampleSimilarity: Float
}

extension GlanceFaceRecognitionPipeline {
    /// Sorted by centroid similarity descending; includes stale identities (different embedder) since `bestMatch` is what excludes them from actually matching.
    nonisolated func score(_ embedding: [Float], against identities: [GlanceFaceIdentity]) -> [GlanceScoredIdentity] {
        identities.compactMap { identity in
            guard let template = identity.template, !identity.samples.isEmpty else { return nil }
            let centroidSim = GlanceFaceEmbedding.cosineSimilarity(embedding, template)
            let maxSim = identity.samples
                .map { GlanceFaceEmbedding.cosineSimilarity(embedding, $0.embedding) }
                .max() ?? centroidSim
            return GlanceScoredIdentity(identity: identity, centroidSimilarity: centroidSim, maxSampleSimilarity: maxSim)
        }.sorted { $0.centroidSimilarity > $1.centroidSimilarity }
    }

    /// Shared by Face Lab and FaceUnlockCoordinator so tuning stays consistent. No runner-up margin check: the same person can be enrolled multiple times under different appearances, so two of their own profiles legitimately score close together — a margin check can't tell that apart from two different people colliding.
    nonisolated func bestMatch(in scored: [GlanceScoredIdentity], threshold: Float) -> GlanceScoredIdentity? {
        guard let first = scored.first, !first.identity.isStale(comparedTo: embedder) else { return nil }
        guard first.centroidSimilarity >= threshold, first.maxSampleSimilarity >= threshold else { return nil }
        return first
    }
}
