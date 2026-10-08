// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Jonathan Zhou
// Adapted from jonnyoo/glance; see ThirdParty/Glance/LICENSE and README.md.
//
//  GlareCue.swift
//  glance
//
//  Pixel-domain half of the gloss/glare cue (see `GlanceLivenessCues.glossGlare`);
//  no Vision/CoreImage import, so it stays usable from `tools/liveness_selftest.swift`.
//  Populated by `GlanceGlareCueExtractor.extract(faceCrop:)`.
//

import CoreGraphics

struct GlanceGlareSample: Equatable {
    /// Native pixel width of the measured crop; `renderCrop` only ever downsamples, so this
    /// is an honest detail measure — the cue confidence-weights down as it shrinks.
    let cropPixelWidth: CGFloat

    /// Fraction of crop pixels that are near-saturated and low-chroma — direct specular reflection.
    let specularFraction: Float

    /// How concentrated the specular pixels are into one region (densest 8x8 grid cell's
    /// share) vs. scattered — distinguishes glass glare from a shiny forehead.
    let specularClusterRatio: Float
}
