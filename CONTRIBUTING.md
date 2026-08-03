# Contributing to GazeAwake

Thank you for helping improve this experimental project.

## Ground rules

- Keep all camera processing local and transparent.
- Do not add telemetry, uploads, hidden recording, or network dependencies.
- Do not describe GazeAwake as precise, professional, medical, or accessibility-certified eye tracking.
- Treat iPhone/iPad attention awareness as product motivation only; never imply technical parity with Face ID/TrueDepth or affiliation with Apple.
- Preserve honest benchmark reporting, including regressions.
- Prefer Apple system frameworks and avoid third-party dependencies unless a proposal clearly justifies the privacy, binary-size, and maintenance trade-offs.

## Development setup

Requirements:

- macOS 13+
- Xcode 15+
- Swift 5.9+

Build without signing:

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

Type-check the notification sample:

```bash
xcrun swiftc -typecheck Samples/NotificationListener.swift \
  -target arm64-apple-macos13.0
```

## Pull requests

1. Open an issue first for significant behavior, privacy, power, or architecture changes.
2. Keep pull requests focused.
3. Explain how the change affects privacy, CPU, memory, and battery use.
4. Include reproduction steps and the exact Mac, macOS, Xcode, build configuration, and measurement tools for performance claims.
5. Update English and Chinese documentation when user-visible behavior changes.
6. Never commit `DerivedData`, local benchmark artifacts, camera frames, signing identities, or provisioning profiles.

## Benchmark contributions

Run a Release build without the Xcode debugger, allow Vision to warm up, and report at least:

- physical footprint and peak physical footprint from `footprint`;
- RSS from `ps`;
- CPU over a stated duration;
- detection mode, resolution, and inference rate;
- Mac model identifier, chip, core count, RAM, macOS, and Xcode version.

Do not include serial numbers, hardware UUIDs, account names, or other private machine identifiers.

## Style

- Use clear Swift names and small focused types.
- Keep capture and Vision work off the main queue.
- Never retain sample buffers after frame processing.
- Release IOKit assertions on every pause, disable, error, and termination path.

By contributing, you agree that your contributions are licensed under the MIT License.
