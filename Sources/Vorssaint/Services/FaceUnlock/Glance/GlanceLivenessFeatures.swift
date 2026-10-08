// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  LivenessFeatures.swift
//  glance
//
//  Vision-facing half of liveness: turns a `GlanceFaceRecognitionResult` into a plain,
//  Vision-free `GlanceLivenessFrame` — keeps the decision logic compilable standalone.
//

import Vision
import CoreGraphics

enum GlanceLivenessFeatureExtractor {
    /// Never fails — a face with no landmarks still yields a frame; cues that need landmarks abstain.
    ///
    /// - Parameter frame: the full camera frame, not `result.alignedImage` (a tightly-cropped
    ///   112x112 warp with no room around the face for `GlanceDeviceBezelDetector` to see a device edge).
    static func extract(
        from result: GlanceFaceRecognitionResult, frame: CGImage, faceCrop: CGImage? = nil, timestamp: Date = Date()
    ) -> GlanceLivenessFrame {
        let face = result.face
        let deviceOverlap = GlanceDeviceBezelDetector.detect(in: frame, faceBoundingBox: face.boundingBox).faceOverlapFraction
        let glare = faceCrop.flatMap { GlanceGlareCueExtractor.extract(faceCrop: $0) }

        guard let landmarks = face.landmarks else {
            return GlanceLivenessFrame(
                timestamp: timestamp, landmarks: [], interocularDistance: nil,
                yaw: face.yaw,
                leftEyeAspectRatio: nil, rightEyeAspectRatio: nil,
                noseOffsetRatio: nil,
                hasReliableLandmarks: false,
                deviceOverlapFraction: deviceOverlap,
                glare: glare
            )
        }

        let imageSize = face.imageSize
        let points = GlanceLandmarkGeometry.allPoints(from: landmarks, imageSize: imageSize)
        let interocular = GlanceLandmarkGeometry.interocularDistance(from: landmarks, imageSize: imageSize)
        let leftEAR = landmarks.leftEye.flatMap { GlanceLandmarkGeometry.eyeAspectRatio(of: $0, imageSize: imageSize) }
        let rightEAR = landmarks.rightEye.flatMap { GlanceLandmarkGeometry.eyeAspectRatio(of: $0, imageSize: imageSize) }

        let eyeLeft = GlanceLandmarkGeometry.eyeCenter(pupil: landmarks.leftPupil, eye: landmarks.leftEye, imageSize: imageSize)
        let eyeRight = GlanceLandmarkGeometry.eyeCenter(pupil: landmarks.rightPupil, eye: landmarks.rightEye, imageSize: imageSize)

        var noseOffsetRatio: CGFloat?
        if let interocular, interocular > 0, let eyeLeft, let eyeRight,
           let nose = landmarks.nose, let noseCenter = GlanceLandmarkGeometry.centroid(of: nose, imageSize: imageSize) {
            let eyeMidX = (eyeLeft.x + eyeRight.x) / 2
            noseOffsetRatio = (noseCenter.x - eyeMidX) / interocular
        }

        return GlanceLivenessFrame(
            timestamp: timestamp,
            landmarks: points,
            interocularDistance: interocular,
            yaw: face.yaw,
            leftEyeAspectRatio: leftEAR, rightEyeAspectRatio: rightEAR,
            noseOffsetRatio: noseOffsetRatio,
            hasReliableLandmarks: result.alignmentTier == .fivePoint,
            deviceOverlapFraction: deviceOverlap,
            glare: glare
        )
    }
}
