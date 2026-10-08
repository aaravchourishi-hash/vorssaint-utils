// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

@preconcurrency import AVFoundation
import AppKit
import CoreImage

@MainActor
final class FaceUnlockCamera: ObservableObject {
    struct Frame {
        let id: UInt64
        let image: CGImage
        let capturedAt: TimeInterval
    }
    @Published private(set) var isRunning = false
    @Published private(set) var error: String?
    private(set) var frame: Frame?
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.vorssaint.face-unlock.camera")
    private let worker = CaptureWorker()
    private var generation = 0

    static var devices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                        mediaType: .video, position: .unspecified).devices
    }

    func start(cameraID: String, requestPermission: Bool) async -> Bool {
        generation &+= 1
        let token = generation
        error = nil
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined, requestPermission {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        guard token == generation, !Task.isCancelled else { return false }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            error = FaceUnlockStrings.current[.cameraDenied]
            return false
        }
        // A disconnected selected camera must not silently switch to another camera.
        let device = cameraID.isEmpty
            ? (Self.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) ?? Self.devices.first)
            : Self.devices.first(where: { $0.uniqueID == cameraID })
        guard let device else { error = FaceUnlockStrings.current[.noCamera]; return false }
        let failure: String? = await withCheckedContinuation { continuation in
            queue.async { [weak self, session, worker, queue] in
                do {
                    try worker.start(session: session, device: device, queue: queue) { [weak self] frame in
                        Task { @MainActor [weak self] in
                            guard let self, self.generation == token, self.isRunning else { return }
                            self.frame = frame
                        }
                    }
                    continuation.resume(returning: nil)
                } catch { continuation.resume(returning: error.localizedDescription) }
            }
        }
        guard token == generation, !Task.isCancelled else { return false }
        error = failure
        isRunning = failure == nil
        return isRunning
    }

    func stop() {
        generation &+= 1
        isRunning = false
        frame = nil
        queue.async { [session, worker] in
            if session.isRunning { session.stopRunning() }
            worker.deliver = nil
        }
    }
}

/// All session configuration and image processing stay on the serial capture queue.
private final class CaptureWorker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    var deliver: ((FaceUnlockCamera.Frame) -> Void)?
    private let context = CIContext()
    private var nextID: UInt64 = 0

    func start(session: AVCaptureSession, device: AVCaptureDevice, queue: DispatchQueue,
               deliver: @escaping (FaceUnlockCamera.Frame) -> Void) throws {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        do {
            session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            guard session.canAddInput(input), session.canAddOutput(output) else {
                throw CocoaError(.featureUnsupported)
            }
            session.addInput(input)
            session.addOutput(output)
            output.setSampleBufferDelegate(self, queue: queue)
            session.commitConfiguration()
        } catch {
            session.commitConfiguration()
            throw error
        }
        self.deliver = deliver
        session.startRunning()
        guard session.isRunning else { throw CocoaError(.fileReadUnknown) }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer), let deliver else { return }
        let source = CIImage(cvPixelBuffer: buffer)
        guard let image = context.createCGImage(source, from: source.extent) else { return }
        nextID &+= 1
        deliver(FaceUnlockCamera.Frame(id: nextID, image: image,
                                      capturedAt: ProcessInfo.processInfo.systemUptime))
    }
}
