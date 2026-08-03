import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

final class CameraManager: NSObject {
    enum CameraError: LocalizedError {
        case unavailable
        case permissionDenied
        case inputUnavailable
        case outputUnavailable

        var errorDescription: String? {
            switch self {
            case .unavailable: return "No camera is available."
            case .permissionDenied: return "Camera permission is denied."
            case .inputUnavailable: return "The camera could not be configured."
            case .outputUnavailable: return "The video output could not be configured."
            }
        }
    }

    var onStateChanged: ((Bool) -> Void)?
    var onRunningChanged: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?

    private let session = AVCaptureSession()
    // Session control and frame processing share one serial queue. This prevents
    // overlapping Vision requests and avoids an extra worker thread/stack.
    private let sessionQueue = DispatchQueue(label: "net.xgxgx.gazeawake.camera",
                                              qos: .utility,
                                              autoreleaseFrequency: .workItem)
    private let output = AVCaptureVideoDataOutput()
    private let detector = GazeDetector()
    private var isConfigured = false
    private var frameNumber: UInt64 = 0
    private let processEveryNthFrame: UInt64 = 3 // 12 fps capture -> 4 fps Vision work

    override init() {
        super.init()
        detector.onStateChanged = { [weak self] state in
            self?.onStateChanged?(state)
        }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted { self.configureAndStart() }
                else { self.report(CameraError.permissionDenied) }
            }
        case .denied, .restricted:
            report(CameraError.permissionDenied)
        @unknown default:
            report(CameraError.permissionDenied)
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.stopOnSessionQueue()
        }
    }

    func toggle() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.stopOnSessionQueue()
            } else {
                DispatchQueue.main.async { [weak self] in self?.start() }
            }
        }
    }

    private func stopOnSessionQueue() {
        if session.isRunning { session.stopRunning() }
        frameNumber = 0
        detector.reset()
        DispatchQueue.main.async { [weak self] in self?.onRunningChanged?(false) }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.isConfigured {
                    try self.configure()
                    self.configureTargetFrameRate()
                }
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                DispatchQueue.main.async { [weak self] in self?.onRunningChanged?(true) }
            } catch {
                self.report(error)
            }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.unavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.inputUnavailable }
        session.addInput(input)

        // Prefer an explicit 320x240 format, then fall back through small presets.
        let presets: [AVCaptureSession.Preset] = [.qvga320x240, .cif352x288, .vga640x480, .low]
        if let preset = presets.first(where: { session.canSetSessionPreset($0) }) {
            session.sessionPreset = preset
        }

        guard session.canAddOutput(output) else { throw CameraError.outputUnavailable }
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }
        isConfigured = true
    }

    private func configureTargetFrameRate() {
        guard let deviceInput = session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }).first else { return }
        let device = deviceInput.device
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= 12 && $0.maxFrameRate >= 12
        }) else { return }
        do {
            try device.lockForConfiguration()
            let frameDuration = CMTime(value: 1, timescale: 12)
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            device.unlockForConfiguration()
        } catch {
            // Keep the camera driver's default rate; frame skipping still caps Vision work.
        }
    }

    private func report(_ error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onError?(error) }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frameNumber &+= 1
        guard frameNumber % processEveryNthFrame == 0 else { return }
        autoreleasepool {
            detector.process(sampleBuffer: sampleBuffer)
        }
        // No frame is cached or dispatched asynchronously; sampleBuffer goes out of scope
        // as soon as this callback returns.
    }
}
