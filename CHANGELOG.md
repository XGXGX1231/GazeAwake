# Changelog

All notable changes to GazeAwake are documented here. The project follows semantic versioning while APIs remain experimental.

## [Unreleased]

### Planned

- Low-power face-presence mode
- Sensitivity presets and optional calibration
- Launch at login
- Unit tests and broader hardware benchmarks
- Screenshots and demonstration GIF

## [0.1.0] - 2026-08-04

### Added

- Native macOS menu bar agent with `LSUIElement`
- Low-resolution, 12 fps AVFoundation capture
- Vision face-landmark, pupil-position, and head-pose heuristic
- Debounced looking/not-looking state callback
- Local and distributed notifications
- Display wake on attention return
- Keep-display-awake assertion while looking
- Pause, resume, wake toggle, camera settings, and quit menu actions
- Camera sandbox entitlement and privacy usage description
- Resource monitoring and notification-listener scripts
- English and Simplified Chinese documentation
- Reproducible Apple M5 benchmark disclosure

### Known limitations

- Landmark mode exceeds the original 20 MB / 5% CPU goal
- Pupil-unavailable fallback uses coarse face/head orientation
- No full-system-sleep wake or authentication bypass
- No calibration, low-power mode, login item, or automated unit tests yet
