// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import AVFoundation

@MainActor
struct FaceUnlockSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = FaceUnlockService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.faceUnlockConsent) private var consent = false
    @AppStorage(DefaultsKey.faceUnlockEnabled) private var enabled = false
    @AppStorage(DefaultsKey.faceUnlockIndicator) private var indicator = true
    @AppStorage(DefaultsKey.faceUnlockCamera) private var cameraID = ""
    @State private var password = ""
    @State private var confirmForget = false
    @State private var cameras: [AVCaptureDevice] = []
    private var text: FaceUnlockStrings { FaceUnlockStrings(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsRow(symbol: "faceid", title: text[.title], badge: "Glance · Beta", caption: text[.summary]) {
                    Toggle(text[.enable], isOn: Binding(get: { enabled }, set: { service.setEnabled($0) }))
                        .labelsHidden().toggleStyle(.switch)
                        .disabled(!enabled && (!service.ready || !consent || !permissions.accessibility))
                }
                notice
                if consent {
                    session
                    permissionsCard
                    credentials
                    enrollment
                    SettingsCard {
                        Toggle(text[.indicator], isOn: $indicator)
                        Text(text[.privacy]).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if service.hasStoredSetup || service.authorized {
                    Button(text[.forget], role: .destructive) { confirmForget = true }
                        .disabled(service.busy)
                }
                HStack {
                    Link(text[.learnMore], destination: URL(string: "https://github.com/jonnyoo/glance")!)
                    Spacer()
                }.font(.caption)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { cameras = FaceUnlockCamera.devices; service.syncWithPreferences() }
        .onDisappear { password = ""; service.closeSetup() }
        .onChange(of: consent) { _, value in
            if !value { password = ""; service.setEnabled(false); service.pauseSession() }
        }
        .confirmationDialog(text[.forgetConfirm], isPresented: $confirmForget, titleVisibility: .visible) {
            Button(text[.delete], role: .destructive) { password = ""; service.forget() }
            Button(text[.cancel], role: .cancel) {}
        }
    }

    private var notice: some View {
        SettingsCard {
            Label(text[.notice], systemImage: "exclamationmark.shield")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Toggle(text[.accept], isOn: $consent)
        }
    }

    private var session: some View {
        SettingsCard {
            SettingsRow(symbol: service.authorized ? "lock.open" : "lock.shield",
                        title: text[service.status == .sessionHint ? .authorize : service.status],
                        caption: text[.sessionHint]) {
                if service.busy { ProgressView().controlSize(.small).accessibilityLabel(text[.setup]) }
                Button(text[service.authorized ? .pause : .authorize]) {
                    if service.authorized { password = ""; service.pauseSession() } else { service.authorize() }
                }.disabled(service.busy)
            }
            if let detail = service.detail {
                Text(detail).font(.caption).foregroundStyle(.orange)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionsCard: some View {
        SettingsCard(title: text[.permissions]) {
            if !permissions.accessibility { PermissionRow(kind: .accessibility) }
            if AVCaptureDevice.authorizationStatus(for: .video) == .denied
                || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                SettingsRow(symbol: "web.camera", title: text[.camera], caption: text[.cameraDenied]) {
                    Button(l10n.s.permissionOpenSettings) { permissions.openCameraSettings() }
                }
            } else {
                Text(text[.cameraUse]).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var credentials: some View {
        SettingsCard(title: text[.password]) {
            HStack {
                SecureField(text[.password], text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { savePassword() }
                Button(text[.save]) { savePassword() }
                    .disabled(password.isEmpty || !service.authorized || service.busy || service.enrolling)
            }.disabled(!service.authorized)
            if service.passwordSaved {
                Label(text[.saved], systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var enrollment: some View {
        SettingsCard(title: text[.enroll]) {
            Picker(text[.camera], selection: $cameraID) {
                Text(text[.automatic]).tag("")
                ForEach(cameras, id: \.uniqueID) { camera in Text(camera.localizedName).tag(camera.uniqueID) }
                if !cameraID.isEmpty, !cameras.contains(where: { $0.uniqueID == cameraID }) {
                    Text(text[.noCamera]).tag(cameraID)
                }
            }.disabled(service.enrolling || service.busy)
            if service.enrolling {
                FaceUnlockCameraPreview(session: service.camera.session)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel(text[.camera])
                Text(text[service.status]).font(.headline)
                Text(text[.faceHint]).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: Double(service.sampleCount), total: Double(FaceUnlockPolicy.sampleCount))
                    .accessibilityLabel(text[.enroll])
                HStack {
                    Button(text[.capture]) { service.captureSample() }
                        .buttonStyle(.borderedProminent).disabled(service.busy)
                    Text("\(service.sampleCount) / \(FaceUnlockPolicy.sampleCount)")
                        .monospacedDigit().foregroundStyle(.secondary)
                    Spacer()
                    Button(text[.cancel]) { service.closeSetup() }
                }
            } else {
                SettingsRow(symbol: service.faceEnrolled ? "checkmark.circle" : "person.crop.rectangle",
                            title: text[service.faceEnrolled ? .saved : .enroll], caption: text[.faceHint]) {
                    Button(text[service.faceEnrolled ? .recapture : .enroll]) { service.beginEnrollment() }
                        .disabled(!service.authorized || service.busy)
                }
            }
        }
    }

    private func savePassword() {
        guard service.authorized, !service.busy, !service.enrolling, !password.isEmpty else { return }
        let value = password
        password = ""
        service.savePassword(value)
    }
}

private struct FaceUnlockCameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    func makeNSView(context: Context) -> FaceUnlockPreviewHost { FaceUnlockPreviewHost(session) }
    func updateNSView(_ nsView: FaceUnlockPreviewHost, context: Context) {}
}

private final class FaceUnlockPreviewHost: NSView {
    private let preview: AVCaptureVideoPreviewLayer
    init(_ session: AVCaptureSession) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        preview.videoGravity = .resizeAspectFill
        layer?.addSublayer(preview)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        preview.bounds = bounds
        preview.position = CGPoint(x: bounds.midX, y: bounds.midY)
        preview.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        CATransaction.commit()
    }
}
