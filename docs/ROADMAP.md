# Roadmap

GazeAwake is experimental. Roadmap items are research directions, not commitments.

## v0.2 candidates

### Low-power mode

- Evaluate `AVCaptureMetadataOutput` face metadata.
- Evaluate `VNDetectFaceRectanglesRequest` at 1–2 fps.
- Document the accuracy and memory trade-off against landmarks mode.
- Never label face presence as precise eye gaze.

### Sensitivity and calibration

- Strict, balanced, and permissive presets.
- Optional short per-user neutral-pose calibration.
- Adjustable positive/negative debounce.

### App lifecycle

- Optional launch at login using supported ServiceManagement APIs.
- Better camera interruption and device-disconnection handling.
- State timeout/heartbeat for notification consumers.

### Quality

- Extract pure scoring and debounce types for unit testing.
- Add tests for notification payloads and assertion lifecycle.
- Add screenshots and a short demo GIF.
- Benchmark Intel, M1–M5, and multiple macOS versions.

## Non-goals

- Medical, professional, or accessibility-certified eye tracking
- Identity recognition or biometric profiling
- Hidden camera operation
- Remote video processing
- Password, lock-screen, or Touch ID bypass
- Waking a closed-lid or fully sleeping Mac through camera analysis
- Claiming universal memory or CPU limits that cannot be measured and enforced
