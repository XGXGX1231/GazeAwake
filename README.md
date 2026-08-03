# GazeAwake — Gaze Awareness for MacBook

**A privacy-first experiment that brings a familiar attention-aware display experience to MacBook using only native Swift frameworks.**

[![Build](https://github.com/XGXGX1231/GazeAwake/actions/workflows/build.yml/badge.svg)](https://github.com/XGXGX1231/GazeAwake/actions/workflows/build.yml)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://github.com/XGXGX1231/GazeAwake)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[简体中文](README.zh-CN.md) · [Architecture](docs/ARCHITECTURE.md) · [Benchmarks](docs/BENCHMARKS.md) · [Privacy](docs/PRIVACY.md) · [Roadmap](docs/ROADMAP.md)

> [!WARNING]
> GazeAwake is a **v0.1 proof of concept**. It is not an accurate eye tracker, accessibility device, professional measurement tool, or medical product. The current Vision-landmarks mode has significant measured memory and CPU usage; see [Benchmarks](docs/BENCHMARKS.md) for the observed values and methodology.

## Why GazeAwake exists

People who use attention-aware behavior on compatible Face ID-equipped iPhone and iPad devices can become accustomed to the display responding to their attention. After moving back to a MacBook, the absence of the same gaze-to-display interaction in their workflow can feel surprisingly disruptive: they may still expect the screen to recognize that they have returned, stay awake while they are reading, and resume normal power saving when they look away.

**GazeAwake explores that missing continuity on MacBook.** It uses the Mac camera to approximate one narrow part of that familiar experience:

- look back at the MacBook to wake an idle-sleeping display;
- keep looking to prevent unnecessary idle display sleep;
- look away to return control to normal macOS energy-saving behavior.

This is an independent open-source experiment, not an Apple feature or an implementation of Face ID/TrueDepth attention sensing. It does not attempt to reproduce every Attention Aware feature on iPhone or iPad. Its webcam-based heuristic is less precise and currently much more resource-intensive; the comparison describes the **interaction motivation**, not technical equivalence.

## What it does

GazeAwake is a MacBook-focused menu bar agent with no Dock icon and no main window. It uses the camera to estimate whether the user is looking toward the screen, then closes the loop:

1. Detect coarse attention locally.
2. Wake an idle-sleeping display when attention returns.
3. Keep the display awake while the user keeps looking.
4. Release power assertions when the user looks away, pauses detection, or quits.
5. Publish state changes to other macOS apps.

It uses only:

- **AVFoundation** for low-resolution camera capture
- **Vision** for face landmarks and head pose
- **IOKit** for display wake and idle-display-sleep assertions
- **AppKit** for the menu bar agent

There are no third-party models or packages, no Python, no OpenCV, and no network service. Camera frames are never written to disk or uploaded.

## Detection model

The current mode is a coarse heuristic rather than precise eye tracking:

- Capture at 12 fps, preferring 320×240, 352×288, then 640×480.
- Run `VNDetectFaceLandmarksRequest` on every third frame (~4 inferences/s).
- Select the largest detected face and reject very small faces.
- Reject large head rotations using yaw, roll, and pitch thresholds.
- If pupil landmarks are available, score whether both pupils are near the center of their eye regions.
- If pupil landmarks are unavailable, fall back to **face present + head roughly facing the screen**.
- Debounce with 2 positive samples (~0.5 s) and 3 negative samples (~0.75 s).

See [Architecture](docs/ARCHITECTURE.md) for the exact thresholds and data flow.

## Display behavior

When attention changes to `true`, GazeAwake calls `IOPMAssertionDeclareUserActivity` to wake the display and reset its idle timer. While the user remains looking, it holds a `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertion. The assertion is released when attention becomes false, detection is paused, the wake option is disabled, or the app quits.

GazeAwake can wake a display that turned off because of idle display sleep. It **cannot**:

- wake a Mac from full system/deep sleep;
- run while the camera is suspended;
- wake a closed-lid Mac;
- bypass the lock screen, password, or Touch ID.

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later
- Swift 5.9 or later
- A MacBook camera or compatible external Mac camera

The project has no package-manager dependencies.

## Download and install

Download `GazeAwake-v0.1.0-macOS-universal.dmg` from the [v0.1.0 Release](https://github.com/XGXGX1231/GazeAwake/releases/tag/v0.1.0), open it, and drag `GazeAwake.app` to **Applications**. The Universal app supports both Apple Silicon and Intel Macs.

The current experimental DMG is ad-hoc signed and **not Apple-notarized** because the project does not yet have a Developer ID certificate. macOS may block its first launch. Try opening GazeAwake once, then go to **System Settings → Privacy & Security → Security → Open Anyway**, confirm the launch, and approve camera access. Only install a DMG downloaded from the official GitHub Release page.

## Build and run

1. Open `GazeAwake.xcodeproj` in Xcode.
2. Select the `GazeAwake` scheme and **My Mac**.
3. Choose a signing team if Xcode requests one.
4. Run the app and approve camera access.
5. Use the eye icon in the menu bar to pause, resume, toggle wake behavior, or quit.

Command-line Release build:

```bash
./Scripts/build-release.sh
```

Unsigned CI-style build:

```bash
xcodebuild \
  -project GazeAwake.xcodeproj \
  -scheme GazeAwake \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath work/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Test display wake

1. Look away until the menu reports that you are not looking.
2. Run `pmset displaysleepnow` in Terminal while still looking away.
3. Look back toward the camera.
4. The display should wake after the positive debounce interval, normally around 0.5 seconds.

## State integration

In-process callback:

```swift
cameraManager.onStateChanged = { isLookingAtScreen in
    print(isLookingAtScreen)
}
```

Notifications emitted on confirmed state changes:

| Channel | Name |
|---|---|
| `NotificationCenter` | `GazeAwakeStateDidChange` |
| `DistributedNotificationCenter` | `net.xgxgx.GazeAwake.stateDidChange` |

Payload:

```swift
["isLookingAtScreen": Bool]
```

Run the listener example:

```bash
swift Samples/NotificationListener.swift
```

Consumers should implement a timeout because a force-terminated process cannot publish a final `false` state.

## Honest performance status

Measured on an Apple M5 MacBook Pro after Vision warm-up:

| Metric | Result |
|---|---:|
| Active physical footprint | ~207 MiB / 217 MB |
| Peak physical footprint | ~292 MiB / 306 MB |
| Vision neural peak | ~126 MiB / 132 MB |
| `ps` RSS | ~104 MiB / 107 MB |
| Short CPU sample | ~21–27% |

The 11–12 MB startup footprint observed before active camera/Vision processing is not representative of real detection. The dominant cost is Vision's neural and landmark-processing resources, not retained video frames.

See [Benchmarks](docs/BENCHMARKS.md) for the test machine, methodology, metric definitions, and limitations.

## Privacy

- Frames are processed synchronously in memory.
- No frame cache is maintained by the app.
- Frames are not saved, uploaded, logged, or sent over a network.
- No analytics or telemetry is included.
- The camera remains active while detection is running, so the macOS camera indicator is expected to be visible.

Read the complete [Privacy Model](docs/PRIVACY.md).

## Known limitations

- Coarse attention estimation, not precise gaze tracking.
- Pupil failure falls back to head-facing-screen logic and can produce false positives.
- Glasses, glare, backlighting, face angle, camera placement, and individual eye geometry affect results.
- Current landmark mode is expensive in memory and CPU.
- It cannot detect attention while the Mac or camera is suspended.
- It wakes the display but never unlocks the Mac.
- Thresholds are not calibrated per user in v0.1.

## Roadmap

Planned experiments include:

- a low-power face-presence mode;
- sensitivity presets and per-user calibration;
- launch at login;
- unit tests for debounce and scoring logic;
- screenshots and a short demonstration GIF;
- longer benchmark runs across multiple Mac generations.

See [Roadmap](docs/ROADMAP.md). Contributions and reproducible benchmark reports are welcome.

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Please report security or privacy issues through a private GitHub Security Advisory rather than a public issue.

## License

GazeAwake is available under the [MIT License](LICENSE).

Apple, iPhone, iPad, MacBook, Face ID, and TrueDepth are trademarks of Apple Inc. GazeAwake is an independent project and is not affiliated with or endorsed by Apple.
