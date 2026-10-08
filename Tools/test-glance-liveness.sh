#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
sources=Sources/Vorssaint/Services/FaceUnlock/Glance
swiftc -O -o build/glance-liveness-tests \
    "$sources/GlanceLandmarkGeometry.swift" \
    "$sources/GlanceGeometryLiveness.swift" \
    "$sources/GlanceGlareCue.swift" \
    "$sources/GlanceLivenessCues.swift" \
    "$sources/GlanceLivenessScoring.swift" \
    "$sources/GlanceLivenessAnalyzer.swift" \
    ThirdParty/Glance/LivenessSelfTest.swift
./build/glance-liveness-tests
