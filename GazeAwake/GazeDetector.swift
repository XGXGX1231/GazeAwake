import Foundation
import Vision
import CoreMedia
import CoreVideo

/// Lightweight, heuristic gaze estimator built on Vision face landmarks and head pose.
/// It deliberately avoids retaining images, pixel buffers, or ML models.
final class GazeDetector {
    static let stateDidChangeNotification = Notification.Name("GazeAwakeStateDidChange")
    static let distributedStateNotification = Notification.Name("net.xgxgx.GazeAwake.stateDidChange")

    var onStateChanged: ((Bool) -> Void)?

    private let request: VNDetectFaceLandmarksRequest
    private var lastState: Bool?
    private var consecutiveLooking = 0
    private var consecutiveAway = 0
    private let lookingConfirmationFrames = 2
    private let awayConfirmationFrames = 3

    init() {
        request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
    }

    /// Processes one frame synchronously. The caller must not retain the sample buffer.
    func process(sampleBuffer: CMSampleBuffer) {
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // The capture output already supplies an upright landscape pixel buffer.
            // The heuristic is symmetric, so mirroring does not change its result.
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                orientation: .up,
                                                options: [:])
            do {
                try handler.perform([request])
                let observations = request.results ?? []
                let looking = estimateLooking(observations)
                updateState(with: looking)
            } catch {
                // A transient Vision error is treated as an away sample, not as a state
                // change by itself. This prevents a single dropped frame from flapping.
                updateState(with: false)
            }
        }
    }

    func reset() {
        consecutiveLooking = 0
        consecutiveAway = 0
        if lastState != false {
            lastState = false
            emitState(false)
        }
    }

    private func estimateLooking(_ observations: [VNFaceObservation]) -> Bool {
        guard let face = observations.max(by: { $0.boundingBox.width * $0.boundingBox.height <
            $1.boundingBox.width * $1.boundingBox.height }) else { return false }

        // Reject tiny detections (typically background false positives).
        guard face.boundingBox.width * face.boundingBox.height >= 0.018 else { return false }

        // Head pose is intentionally permissive: this is awareness, not biometric eye
        // tracking. Vision returns radians for these values when available.
        if let yaw = face.yaw?.doubleValue, abs(yaw) > 0.48 { return false }
        if let roll = face.roll?.doubleValue, abs(roll) > 0.58 { return false }
        if let pitch = face.pitch?.doubleValue, abs(pitch) > 0.55 { return false }

        guard let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return true
        }

        // Pupil positions are normalized inside each eye region. Looking toward the
        // center of the screen means both pupils remain near the middle of their eyes.
        guard let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            return true
        }

        let leftScore = centeredPupilScore(pupil: leftPupil, eye: leftEye)
        let rightScore = centeredPupilScore(pupil: rightPupil, eye: rightEye)
        return leftScore >= 0.28 && rightScore >= 0.28
    }

    private func centeredPupilScore(pupil: VNFaceLandmarkRegion2D,
                                    eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let eyePoints = eye.normalizedPoints
        let pupilPoints = pupil.normalizedPoints
        guard !eyePoints.isEmpty, !pupilPoints.isEmpty else { return 0 }

        let minX = eyePoints.map(\.x).min() ?? 0
        let maxX = eyePoints.map(\.x).max() ?? 1
        let minY = eyePoints.map(\.y).min() ?? 0
        let maxY = eyePoints.map(\.y).max() ?? 1
        let pupilX = pupilPoints.map(\.x).reduce(0, +) / CGFloat(pupilPoints.count)
        let pupilY = pupilPoints.map(\.y).reduce(0, +) / CGFloat(pupilPoints.count)
        let width = max(maxX - minX, 0.0001)
        let height = max(maxY - minY, 0.0001)
        let normalizedX = (pupilX - minX) / width
        let normalizedY = (pupilY - minY) / height
        let horizontal = max(0, 1 - abs(normalizedX - 0.5) / 0.5)
        let vertical = max(0, 1 - abs(normalizedY - 0.5) / 0.5)
        return horizontal * 0.75 + vertical * 0.25
    }

    private func updateState(with looking: Bool) {
        if looking {
            consecutiveLooking += 1
            consecutiveAway = 0
            if lastState != true && consecutiveLooking >= lookingConfirmationFrames {
                lastState = true
                emitState(true)
            }
        } else {
            consecutiveAway += 1
            consecutiveLooking = 0
            if lastState != false && consecutiveAway >= awayConfirmationFrames {
                lastState = false
                emitState(false)
            }
        }
    }

    private func emitState(_ isLooking: Bool) {
        let userInfo: [AnyHashable: Any] = ["isLookingAtScreen": isLooking]
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onStateChanged?(isLooking)
            NotificationCenter.default.post(name: Self.stateDidChangeNotification,
                                            object: nil,
                                            userInfo: userInfo)
            DistributedNotificationCenter.default().postNotificationName(
                Self.distributedStateNotification,
                object: nil,
                userInfo: userInfo,
                deliverImmediately: true
            )
        }
    }
}
