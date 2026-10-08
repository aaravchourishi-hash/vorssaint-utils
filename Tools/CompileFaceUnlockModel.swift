// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation
import CoreML

// Core ML's compiler also ships with Command Line Tools; no Xcode dependency.
guard CommandLine.arguments.count == 3 else { exit(2) }
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments[2])
do {
    let compiled = try MLModel.compileModel(at: source)
    defer { try? FileManager.default.removeItem(at: compiled) }
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: compiled, to: destination)
} catch {
    fputs("Face unlock model compilation failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
