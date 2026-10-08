// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
import Foundation
import CoreGraphics

enum FaceUnlockTests {
    static func run(_ suite: TestSuite) {
        func requirement(missing: Int? = nil, busy: Bool = false) -> FaceUnlockText? {
            let states = (0..<6).map { $0 != missing }
            return FaceUnlockPolicy.setupRequirement(consent: states[0], authorized: states[1], passwordSaved: states[2],
                                                     faceEnrolled: states[3], cameraGranted: states[4], accessibilityGranted: states[5], busy: busy)
        }
        let steps: [FaceUnlockText] = [.accept, .authorize, .save, .enroll, .cameraDenied, .permissions]
        for (index, step) in steps.enumerated() {
            suite.expect(requirement(missing: index) == step, "enable switch explains missing setup step \(index)")
        }
        suite.expect(requirement() == nil, "complete setup releases the enable switch")
        suite.expect(requirement(busy: true) == .setup, "in-flight setup cannot enable scanning")
        // Every authorization gate is necessary; a stale or partial setup cannot scan.
        func canScan(_ missing: Int? = nil) -> Bool {
            let values = (0..<10).map { $0 != missing }
            return FaceUnlockPolicy.canScan(installed: values[0], enabled: values[1], consent: values[2],
                                            sessionAuthorized: values[3], passwordSaved: values[4], faceEnrolled: values[5],
                                            cameraGranted: values[6], accessibilityGranted: values[7],
                                            locked: values[8], onConsole: values[9], sleeping: false, submitted: false)
        }
        suite.expect(canScan(), "a fully configured locked session may scan")
        for gate in 0..<10 { suite.expect(!canScan(gate), "missing gate \(gate) refuses scanning") }
        for (sleeping, submitted) in [(true, false), (false, true)] {
            suite.expect(!FaceUnlockPolicy.canScan(installed: true, enabled: true, consent: true,
                                                   sessionAuthorized: true, passwordSaved: true, faceEnrolled: true,
                                                   cameraGranted: true, accessibilityGranted: true, locked: true,
                                                   onConsole: true, sleeping: sleeping, submitted: submitted),
                         "sleep or a prior password submission blocks scanning")
        }
        suite.expect(FaceUnlockPolicy.matches(centroid: 0.8, sample: 0.8, modelMatches: true), "matching face passes threshold")
        for value: Float in [0.1, .nan, .infinity, -.infinity] {
            suite.expect(!FaceUnlockPolicy.matches(centroid: value, sample: 0.9, modelMatches: true), "invalid centroid fails closed")
            suite.expect(!FaceUnlockPolicy.matches(centroid: 0.9, sample: value, modelMatches: true), "invalid sample fails closed")
        }
        suite.expect(!FaceUnlockPolicy.matches(centroid: 1, sample: 1, modelMatches: false), "a different model never matches")
        for (index, yaw, pitch) in [(0, Float(0), Float(0)), (1, 0.3, 0), (2, -0.3, 0), (3, 0, -0.2), (4, 0, 0.2)] {
            suite.expect(FaceUnlockPolicy.acceptsPose(index: index, yaw: yaw, pitch: pitch), "guided pose \(index) accepts a clear view")
        }
        suite.expect(!FaceUnlockPolicy.acceptsPose(index: 1, yaw: 0, pitch: 0), "five repeated straight views do not complete enrollment")
        suite.expect(!FaceUnlockPolicy.acceptsPose(index: 0, yaw: nil, pitch: nil), "missing pose observations are rejected")
        suite.expect(!FaceUnlockPolicy.acceptsPose(index: 0, yaw: .nan, pitch: 0), "invalid pose observations are rejected")
        let face = UUID()
        suite.expect(FaceUnlockPolicy.continuesTrack(previous: face, current: face, elapsed: 0.1), "same fresh face keeps liveness")
        suite.expect(!FaceUnlockPolicy.continuesTrack(previous: face, current: UUID(), elapsed: 0.1), "person switch clears liveness")
        suite.expect(!FaceUnlockPolicy.continuesTrack(previous: face, current: nil, elapsed: 0.1), "missing face clears liveness")
        suite.expect(!FaceUnlockPolicy.continuesTrack(previous: face, current: face, elapsed: 1), "stale frame clears liveness")
        let permit = FaceUnlockPermit()
        suite.expect(permit.isValid, "new scan permit is active")
        permit.revoke()
        suite.expect(!permit.isValid, "cancelled scan cannot inject credentials")
        typealias Route = FaceUnlockIndicatorRoute
        suite.expect(Route.resolve(active: true, locked: true, islandEnabled: true, islandVisible: true) == .island,
                     "a visible island owns scan feedback without a duplicate window")
        suite.expect(Route.resolve(active: true, locked: true, islandEnabled: true, islandVisible: false) == .fallback,
                     "missing or rebuilding island uses the independent fallback")
        suite.expect(Route.resolve(active: true, locked: true, islandEnabled: false, islandVisible: true) == .fallback,
                     "a disabled island is never activated by face unlock")
        for active in [false, true] {
            for locked in [false, true] where !active || !locked {
                suite.expect(Route.resolve(active: active, locked: locked, islandEnabled: true, islandVisible: true) == .hidden,
                             "cancelled or unlocked sessions remove all face indicators")
            }
        }
        suite.expect(FaceUnlockIndicatorPhase.submitting.symbol != "lock.open.fill",
                     "submitting credentials never claims the Mac is unlocked")
        let locked: [String: Any] = ["CGSSessionScreenIsLocked": true, kCGSessionOnConsoleKey as String: true,
                                      kCGSessionUserIDKey as String: NSNumber(value: 501)]
        suite.expect(FaceUnlockSession.accepts(locked, userID: 501), "authoritative current-user lock is accepted")
        suite.expect(!FaceUnlockSession.accepts(locked, userID: 502), "a different user's lock is rejected")
        suite.expect(!FaceUnlockSession.accepts([:], userID: 501), "missing session data fails closed")
        for key in ["CGSSessionScreenIsLocked", kCGSessionOnConsoleKey as String] {
            var changed = locked; changed[key] = false
            suite.expect(!FaceUnlockSession.accepts(changed, userID: 501), "unlocked or inactive console rejects injection")
        }
        suite.expect(!AppFeature.faceUnlock.installedByDefault, "face unlock is opt-in")
        suite.expect(AppFeature.faceUnlock.permissions == [.camera, .accessibility], "camera and accessibility are disclosed")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.faceUnlockEnabled] as? Bool == false, "never enabled by default")
        let keys = SettingsBackupSupport.exportKeys()
        suite.expect(!keys.contains(DefaultsKey.faceUnlockEnabled) && !keys.contains(DefaultsKey.faceUnlockConsent)
                     && !keys.contains(DefaultsKey.faceUnlockCamera), "private device setup is never exported")
        suite.expect(keys.contains(DefaultsKey.faceUnlockIndicator), "the ordinary appearance preference is portable")
        let domain = "com.vorssaint.tests.face-unlock"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        AppFeature.faceUnlock.enableOnFirstInstall(in: defaults, savedValues: [:])
        suite.expect(!defaults.bool(forKey: DefaultsKey.faceUnlockEnabled), "install does not authorize biometric unlock")
        for language in AppLanguage.allCases {
            suite.expect(FaceUnlockStrings.translations[language]?.count == FaceUnlockText.allCases.count,
                         "face unlock translations cover \(language.rawValue)")
            suite.expect(FaceUnlockStrings.translations[language]?.allSatisfy { !$0.isEmpty } == true,
                         "no empty face unlock translations in \(language.rawValue)")
        }
    }
}
