// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Combine
import OpenDirectory

/// One owner for setup, camera work and lock-screen attempts. Disabled features
/// leave no observer, camera, timer, credential session or overlay running.
@MainActor
final class FaceUnlockService: ObservableObject {
    static let shared = FaceUnlockService()
    let camera = FaceUnlockCamera()
    @Published private(set) var authorized = false
    @Published private(set) var passwordSaved = false
    @Published private(set) var faceEnrolled = false
    @Published private(set) var busy = false
    @Published private(set) var enrolling = false
    @Published private(set) var sampleCount = 0
    @Published private(set) var status: FaceUnlockText = .sessionHint
    @Published private(set) var detail: String?

    private var authorizationInFlight = false
    private var pipeline: GlanceFaceRecognitionPipeline?
    private var samples: [GlanceFaceSample] = []
    private var operation: Task<Void, Never>?
    private var permit: FaceUnlockPermit?
    private var generation = 0
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var sleeping = false
    private var submittedForLock = false
    private var lastAttempt: TimeInterval = -.infinity
    private let overlay = FaceUnlockOverlay()
    private var settingsSubscription: AnyCancellable?
    private var previouslyEnabled = false

    private init() {
        passwordSaved = GlanceSecureCredentialManager.hasStoredPassword()
        settingsSubscription = SettingsWindowVisibility.shared.$isVisible.dropFirst().sink { [weak self] visible in
            if !visible { MainActor.assumeIsolated { self?.closeSetup() } }
        }
    }

    var setupRequirement: FaceUnlockText? {
        FaceUnlockPolicy.setupRequirement(consent: consented,
                                          authorized: authorized && GlanceSecureCredentialManager.isSessionUnlocked,
                                          passwordSaved: passwordSaved, faceEnrolled: faceEnrolled,
                                          cameraGranted: AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                                          accessibilityGranted: FaceUnlockKeystrokes.isAccessibilityTrusted(),
                                          busy: busy || enrolling)
    }
    var ready: Bool { setupRequirement == nil }
    /// Recovery must remain available even if the wrapping key is missing and
    /// only an encrypted enrollment (no password) survived a previous setup.
    var hasStoredSetup: Bool { passwordSaved || GlanceSecureFaceStore.exists }
    var cameraID: String { UserDefaults.standard.string(forKey: DefaultsKey.faceUnlockCamera) ?? "" }
    var isEnabled: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockEnabled) }
    private var consented: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockConsent) }

    func syncWithPreferences() {
        let disabled = previouslyEnabled && !isEnabled
        previouslyEnabled = isEnabled
        // A settings restore or another app surface can change the switch
        // without calling setEnabled. Revoke that session just as promptly.
        if disabled { pauseSession() }
        guard AppFeature.faceUnlock.isAvailable else { stop(); return }
        if !isEnabled && !authorized && !enrolling && !busy {
            removeObservers()
            return
        }
        guard observers.isEmpty else { return }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked") { [weak self] in
            guard let self else { return }
            if self.enrolling || self.busy { self.cancelWork() }
            self.scheduleScan()
        }
        observe(distributed, "com.apple.screenIsUnlocked") { [weak self] in
            guard !FaceUnlockSession.isLockedForCurrentUser else { return }
            self?.submittedForLock = false
            self?.cancelWork()
        }
        observe(distributed, "com.apple.screensaver.didstop") { [weak self] in self?.wake() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification.rawValue) { [weak self] in self?.sleep() }
        observe(workspace, NSWorkspace.screensDidSleepNotification.rawValue) { [weak self] in self?.sleep() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification.rawValue) { [weak self] in self?.pauseSession() }
        observe(workspace, NSWorkspace.didWakeNotification.rawValue) { [weak self] in self?.wake() }
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue) { [weak self] in self?.wake() }
    }

    func setEnabled(_ enabled: Bool) {
        guard !enabled || (AppFeature.faceUnlock.isAvailable && ready) else {
            status = .setup
            detail = FaceUnlockStrings.current[setupRequirement ?? .setup]
            return
        }
        UserDefaults.standard.set(enabled, forKey: DefaultsKey.faceUnlockEnabled)
        if !enabled { pauseSession(); removeObservers() }
        syncWithPreferences()
        status = enabled ? .ready : .off
    }

    func authorize() {
        guard AppFeature.faceUnlock.isAvailable, consented, !busy, !authorizationInFlight else { return }
        cancelWork()
        busy = true
        detail = nil
        let token = generation
        let permission = FaceUnlockPermit()
        permit = permission
        authorizationInFlight = true
        syncWithPreferences()
        operation = Task {
            defer { self.authorizationInFlight = false }
            do {
                let reason = FaceUnlockStrings.current[.authorize]
                try await GlanceSecureCredentialManager.unlockSession(reason: reason, permit: permission)
                guard self.isCurrent(token) else { return }
                GlanceFaceEnrollmentStore.shared.reloadIfUnlocked()
                if let failure = GlanceFaceEnrollmentStore.shared.loadFailure { throw SetupError.message(failure) }
                self.authorized = true
                self.refreshEnrollment()
                self.status = self.faceEnrolled && self.passwordSaved ? .ready : .setup
            } catch {
                guard self.isCurrent(token) else { return }
                self.detail = error.localizedDescription
                self.status = .failed
            }
            if self.isCurrent(token) { self.busy = false }
        }
    }

    func savePassword(_ password: String) {
        guard authorized, !busy, !enrolling, !password.isEmpty, AppFeature.faceUnlock.isAvailable else { return }
        cancelWork()
        busy = true
        detail = nil
        let token = generation
        let permission = FaceUnlockPermit()
        permit = permission
        operation = Task {
            do {
                try await Task.detached {
                    // Verify without typing, logging or invoking a shell. A typo must never lock out the account.
                    let node = try ODNode(session: ODSession.default(), type: UInt32(kODNodeTypeAuthentication))
                    let user = try node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: nil)
                    try user.verifyPassword(password)
                    guard permission.isValid else { throw CancellationError() }
                    var data = Data(password.utf8)
                    defer { data.resetBytes(in: 0..<data.count) }
                    try GlanceSecureCredentialManager.savePassword(data, permit: permission)
                }.value
                guard self.isCurrent(token) else { return }
                self.passwordSaved = true
                self.status = .saved
            } catch {
                guard self.isCurrent(token) else { return }
                self.status = .failed
                self.detail = error.localizedDescription
            }
            if self.isCurrent(token) { self.busy = false }
        }
    }

    func beginEnrollment() {
        guard authorized, !busy, AppFeature.faceUnlock.isAvailable, consented else { return }
        cancelWork()
        detail = nil
        samples = []
        sampleCount = 0
        enrolling = true
        busy = true
        syncWithPreferences()
        let token = generation
        operation = Task {
            do {
                // Loading Core ML is expensive. Keep it off the UI thread.
                let embedder = try await Task.detached { try GlanceArcFaceEmbedder() }.value
                guard self.isCurrent(token) else { return }
                self.pipeline = GlanceFaceRecognitionPipeline(embedder: embedder)
                guard await self.camera.start(cameraID: self.cameraID, requestPermission: true), self.isCurrent(token) else {
                    if self.isCurrent(token) { self.detail = self.camera.error; self.enrolling = false; self.busy = false }
                    return
                }
                self.busy = false
                self.status = .front
            } catch {
                guard self.isCurrent(token) else { return }
                self.busy = false
                self.enrolling = false
                self.status = .failed
                self.detail = error.localizedDescription
            }
        }
    }

    func captureSample() {
        guard enrolling, !busy, let pipeline, let frame = camera.frame,
              ProcessInfo.processInfo.systemUptime - frame.capturedAt < 0.5 else { return }
        busy = true
        detail = nil
        let token = generation
        let captureIndex = sampleCount
        operation = Task {
            do {
                let result = try await Task.detached {
                    let faces = try GlanceFaceDetector.detectFaces(in: frame.image)
                    guard faces.count == 1, let face = faces.first,
                          face.normalizedBoundingBox.width >= 0.18,
                          (face.quality ?? 0) >= 0.4 else { throw SetupError.capture }
                    return try pipeline.recognize(face, in: frame.image)
                }.value
                guard self.isCurrent(token) else { return }
                guard FaceUnlockPolicy.acceptsPose(index: captureIndex, yaw: result.face.yaw, pitch: result.face.pitch),
                      result.alignmentTier == .fivePoint else { throw SetupError.capture }
                // Every sample must still belong to the same person as the first.
                if let first = self.samples.first,
                   GlanceFaceEmbedding.cosineSimilarity(first.embedding, result.embedding) < FaceUnlockPolicy.matchThreshold {
                    throw SetupError.capture
                }
                self.samples.append(GlanceFaceSample(embedding: result.embedding,
                                                    pose: String(self.sampleCount), capturedAt: Date(), quality: result.quality))
                self.sampleCount = self.samples.count
                if self.sampleCount == FaceUnlockPolicy.sampleCount {
                    let store = GlanceFaceEnrollmentStore.shared
                    _ = try store.commitEnrollment(replacing: store.identities.first?.id, name: "Owner",
                                                   samples: self.samples, embedder: pipeline.embedder)
                    self.camera.stop()
                    self.samples = []
                    self.enrolling = false
                    self.refreshEnrollment()
                    self.status = .saved
                } else {
                    self.status = [.front, .left, .right, .up, .down][self.sampleCount]
                }
            } catch {
                guard self.isCurrent(token) else { return }
                self.detail = error is SetupError ? FaceUnlockStrings.current[.faceHint] : error.localizedDescription
            }
            if self.isCurrent(token) { self.busy = false }
        }
    }

    func closeSetup() {
        if enrolling || busy { cancelWork() }
    }

    func pauseSession() {
        cancelWork()
        GlanceSecureCredentialManager.lockSession()
        GlanceFaceEnrollmentStore.shared.reloadIfUnlocked()
        authorized = false
        faceEnrolled = false
        pipeline = nil
        status = .sessionHint
    }

    func forget() {
        guard !busy else { return }
        setEnabled(false)
        cancelWork()
        do {
            // Remove templates before their wrapping key; propagate filesystem failures.
            try GlanceFaceEnrollmentStore.shared.deleteAll()
            try GlanceSecureCredentialManager.deletePassword()
            UserDefaults.standard.set(false, forKey: DefaultsKey.faceUnlockConsent)
            authorized = false
            passwordSaved = false
            faceEnrolled = false
            pipeline = nil
            status = .setup
            detail = nil
        } catch { status = .failed; detail = error.localizedDescription }
    }

    func stop() {
        pauseSession()
        removeObservers()
        pipeline = nil
    }

    private func refreshEnrollment() {
        let store = GlanceFaceEnrollmentStore.shared
        faceEnrolled = !store.isLocked && store.activeIdentities.contains {
            $0.modelIdentifier == "arcface-w600k_mbf-v1" && $0.samples.count >= FaceUnlockPolicy.sampleCount
        }
        passwordSaved = GlanceSecureCredentialManager.hasStoredPassword()
    }

    private func isCurrent(_ token: Int) -> Bool {
        token == generation && !Task.isCancelled && AppFeature.faceUnlock.isAvailable && consented
    }

    private func cancelWork() {
        generation &+= 1
        permit?.revoke()
        permit = nil
        operation?.cancel()
        operation = nil
        camera.stop()
        overlay.hide()
        busy = false
        enrolling = false
        samples = []
    }

    private func observe(_ center: NotificationCenter, _ name: String, action: @escaping @MainActor () -> Void) {
        let observer = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { action() }
        }
        observers.append((center, observer))
    }
    private func removeObservers() {
        for (center, observer) in observers { center.removeObserver(observer) }
        observers = []
    }
    private func sleep() { sleeping = true; cancelWork() }
    private func wake() { sleeping = false; scheduleScan() }

    private var mayScan: Bool {
        FaceUnlockPolicy.canScan(installed: AppFeature.faceUnlock.isAvailable, enabled: isEnabled,
                                 consent: consented, sessionAuthorized: authorized && GlanceSecureCredentialManager.isSessionUnlocked,
                                 passwordSaved: passwordSaved, faceEnrolled: faceEnrolled,
                                 cameraGranted: AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                                 accessibilityGranted: FaceUnlockKeystrokes.isAccessibilityTrusted(),
                                 locked: FaceUnlockSession.isLockedForCurrentUser, onConsole: true,
                                 sleeping: sleeping, submitted: submittedForLock)
    }

    private func scheduleScan() {
        guard isEnabled, !enrolling, !busy, ProcessInfo.processInfo.systemUptime - lastAttempt > 3 else { return }
        cancelWork()
        let token = generation
        operation = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard self.isCurrent(token), self.mayScan else { return }
            self.lastAttempt = ProcessInfo.processInfo.systemUptime
            await self.scan(token: token)
        }
    }

    private func scan(token: Int) async {
        busy = true
        let permission = FaceUnlockPermit()
        permit = permission
        defer {
            permission.revoke()
            if token == generation { camera.stop(); busy = false; overlay.hide() }
        }
        do {
            if pipeline == nil {
                let embedder = try await Task.detached { try GlanceArcFaceEmbedder() }.value
                guard isCurrent(token), mayScan else { return }
                pipeline = GlanceFaceRecognitionPipeline(embedder: embedder)
            }
            guard let pipeline, await camera.start(cameraID: cameraID, requestPermission: false), isCurrent(token), mayScan else { return }
            status = .scanning
            if UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockIndicator) { overlay.show() }
            let liveness = GlanceLivenessAnalyzer()
            liveness.modeProvider = { .heavy }
            var previousIdentity: UUID?
            var previousTime: TimeInterval = 0
            var lastFrame: UInt64?
            let deadline = ProcessInfo.processInfo.systemUptime + FaceUnlockPolicy.scanDuration
            while isCurrent(token), mayScan, ProcessInfo.processInfo.systemUptime < deadline {
                guard let frame = camera.frame, frame.id != lastFrame,
                      ProcessInfo.processInfo.systemUptime - frame.capturedAt < 0.5 else {
                    try await Task.sleep(for: .milliseconds(35)); continue
                }
                lastFrame = frame.id
                let observation = try await Task.detached { () -> (GlanceFaceRecognitionResult, GlanceLivenessFrame)? in
                    let faces = try GlanceFaceDetector.detectFaces(in: frame.image)
                    guard faces.count == 1, let face = faces.first, face.normalizedBoundingBox.width >= 0.18 else { return nil }
                    let result = try pipeline.recognize(face, in: frame.image)
                    let crop = frame.image.cropping(to: face.boundingBox.insetBy(dx: -face.boundingBox.width * 0.15,
                                                                              dy: -face.boundingBox.height * 0.15))
                    return (result, GlanceLivenessFeatureExtractor.extract(from: result, frame: frame.image, faceCrop: crop))
                }.value
                guard isCurrent(token), mayScan else { return }
                guard let (result, liveFrame) = observation else {
                    previousIdentity = nil; liveness.reset(); continue
                }
                let scores = pipeline.score(result.embedding, against: GlanceFaceEnrollmentStore.shared.activeIdentities)
                let match = scores.first.flatMap {
                    FaceUnlockPolicy.matches(centroid: $0.centroidSimilarity, sample: $0.maxSampleSimilarity,
                                             modelMatches: !$0.identity.isStale(comparedTo: pipeline.embedder)) ? $0 : nil
                }
                guard let match else { previousIdentity = nil; liveness.reset(); continue }
                if !FaceUnlockPolicy.continuesTrack(previous: previousIdentity, current: match.identity.id,
                                                    elapsed: frame.capturedAt - previousTime) { liveness.reset() }
                previousIdentity = match.identity.id
                previousTime = frame.capturedAt
                let decision = liveness.observe(liveFrame).decision
                switch decision {
                case .denied:
                    status = .failed
                    await showScanFailure(token: token)
                    return
                case .pending: break
                case .confirmed:
                    guard isCurrent(token), mayScan, permission.isValid else { return }
                    // Exactly one password submission per lock; a failed password never loops.
                    submittedForLock = true
                    camera.stop()
                    try await Task.detached {
                        guard permission.isValid, FaceUnlockSession.isLockedForCurrentUser else { throw CancellationError() }
                        var password = try GlanceSecureCredentialManager.readPassword()
                        defer { password.resetBytes(in: 0..<password.count) }
                        try FaceUnlockKeystrokes.typeAndReturn(password, permit: permission)
                    }.value
                    guard isCurrent(token) else { return }
                    status = .submitted
                    overlay.update(.submitting)
                    // macOS owns the actual unlock. Its session notification
                    // cancels this brief hold and lets the island open its lock.
                    try await Task.sleep(for: .milliseconds(900))
                    return
                }
                try await Task.sleep(for: .milliseconds(35))
            }
            if isCurrent(token) { status = .timeout; await showScanFailure(token: token) }
        } catch is CancellationError {
            // Disabling, sleeping or leaving the console invalidates the attempt.
        } catch {
            if isCurrent(token) {
                status = .failed
                detail = error.localizedDescription
                await showScanFailure(token: token)
            }
        }
    }

    private func showScanFailure(token: Int) async {
        guard isCurrent(token) else { return }
        camera.stop()
        overlay.update(.failed)
        try? await Task.sleep(for: .milliseconds(1100))
    }

    private enum SetupError: LocalizedError {
        case capture, message(String)
        var errorDescription: String? {
            switch self { case .capture: return "Keep one face in the frame in good light."; case .message(let text): return text }
        }
    }
}
