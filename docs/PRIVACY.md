# Privacy Model

GazeAwake is designed for local, inspectable camera processing.

## Data flow

1. AVFoundation supplies a low-resolution sample buffer.
2. Vision evaluates the buffer synchronously in memory.
3. The app derives a Boolean attention state.
4. The callback returns and the sample buffer is not retained.

## What the app does not do

- It does not record video or audio.
- It does not save still images.
- It does not upload camera frames.
- It does not send analytics or telemetry.
- It does not include a network client or remote service.
- It does not identify people or create biometric profiles.
- It does not attempt to unlock the Mac.

## Camera visibility

The camera remains active while detection is running. Users should expect the macOS camera privacy indicator to remain visible. The menu bar control can pause capture at any time.

## Published state

The app can publish only the confirmed Boolean `isLookingAtScreen` state through local and distributed notifications. Other local processes may observe distributed notifications, so consumers should not attach sensitive data to this channel.

## Permissions

- `NSCameraUsageDescription` explains camera use.
- The sandbox camera entitlement is enabled.
- Display wake uses public IOKit power-management APIs and does not require Accessibility permission.

## Threat boundaries

This proof of concept does not claim resistance against a malicious local administrator, code injection, a compromised OS, or another process with permission to access the camera independently. Users should review the source and build locally when trust is important.
