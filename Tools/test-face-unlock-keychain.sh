#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
swiftc -O -o build/face-unlock-keychain-tests \
    Sources/Vorssaint/Services/FaceUnlock/FaceUnlockAuthorization.swift \
    Sources/Vorssaint/Services/FaceUnlock/Glance/GlanceKeychainManager.swift \
    Tools/Tests/FaceUnlockCredentialChecks.swift
./build/face-unlock-keychain-tests
