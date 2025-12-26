# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickRecorder is a lightweight, high-performance screen recorder for macOS built with SwiftUI. It supports recording screens, windows, applications, mobile devices, and system audio with features like audio loopback recording, mouse highlighting, screen magnifier, and HDR video capture.

**Key Technologies:**
- SwiftUI for the user interface
- ScreenCaptureKit (SCStreamKit) for screen recording
- AVFoundation for video encoding and camera capture
- VideoToolbox for hardware-accelerated encoding

**System Requirements:** macOS 12.3+

## Build Commands

Since this is an Xcode project without command-line build scripts, building must be done through Xcode:

1. Open `QuickRecorder.xcodeproj` in Xcode
2. Build: `Cmd+B`
3. Run: `Cmd+R`

**Note:** Xcode (not just Command Line Tools) is required to build this project.

## Dependencies

This project uses Swift Package Manager with the following dependencies:

- **Sparkle** (2.6.0+): Auto-update framework
- **KeyboardShortcuts** (2.2.4+): Global keyboard shortcut handling
- **SwiftLAME**: MP3 encoding support
- **AECAudioStream**: Audio Echo Cancellation (AEC) support
- **MatrixColorSelector**: Custom color picker UI

Dependencies are managed via Xcode's Swift Package Manager integration and will be fetched automatically when opening the project.

## Architecture

### Core Components

**Recording Engine (`RecordEngine.swift`):**
- Entry point: `prepRecord(type:screens:windows:applications:fastStart:)`
- Configures `SCContentFilter` based on recording type (screen/window/application/area/audio)
- Sets up `SCStreamConfiguration` with resolution, frame rate, codec settings
- Manages audio recording from system and microphone
- Handles the main recording loop via `SCStreamDelegate` and `SCStreamOutput`

**Screen Capture Context (`SCContext.swift`):**
- Centralized state management for recording sessions
- Manages `SCStream`, `AVAssetWriter`, and audio engines
- Key methods:
  - `updateAvailableContent()`: Refreshes available displays/windows/apps
  - `stopRecording()`: Cleanup and file finalization
  - `pauseRecording()`: Toggle pause/resume with timestamp management
  - `mixAudioTracks()`: Combines separate mic and system audio tracks

**AV Context (`AVContext.swift`):**
- Camera overlay recording for presenter mode
- Mobile device (iDevice) recording via AVCaptureSession
- Manages `AVCaptureMovieFileOutput` for device recording

**App Delegate (`QuickRecorderApp.swift`):**
- SwiftUI app lifecycle management
- Global state (windows, permissions, settings)
- Keyboard shortcut registration
- Mouse pointer and screen magnifier overlays
- Version checking with Sparkle updater

### View Models (ViewModel/)

UI components are organized by function:
- `ContentView.swift`: Main recording panel
- `SettingsView.swift`: Preferences/settings UI
- `StatusBar.swift`: Menu bar status display
- `AreaSelector.swift`: Region selection for area recording
- `ScreenSelector.swift`, `WinSelector.swift`, `AppSelector.swift`: Capture target pickers
- `CameraOverlayer.swift`: Camera overlay window for macOS 12/13
- `QmaPlayer.swift`: Multi-track audio (.qma) player/editor
- `VideoEditor.swift`: Post-recording trim interface

### Recording Flow

1. User selects recording target (screen/window/app/area)
2. `prepRecord()` creates `SCContentFilter` with:
   - Included/excluded windows and applications
   - Background handling (wallpaper/solid color/transparent)
   - Desktop file visibility, menu bar inclusion
3. `record()` configures `SCStreamConfiguration`:
   - Resolution (retina scaling via `highRes` setting)
   - Frame rate (defaults to 60fps, configurable)
   - Codec (H.264/H.265/HEVC with Alpha)
   - Audio settings (sample rate, channel count)
4. `SCStream` starts, delegates frames to `stream(_:didOutputSampleBuffer:of:)`
5. Video frames → `AVAssetWriterInput` (vwInput)
6. System audio → `AVAssetWriterInput` (awInput)
7. Microphone → separate `AVAssetWriterInput` (micInput)
8. On stop: finalize writers, optionally mix audio tracks, show preview

### Special Features

**Presenter Overlay (macOS 14+):**
- Uses ScreenCaptureKit's built-in presenter overlay API
- Detects overlay state changes via `presenterOverlayContentRect` attachment
- Implements safety delay (`poSafeDelay`) to avoid capturing transition frames

**Audio Echo Cancellation:**
- Optional AEC via `AECAudioStream` library
- Processes microphone input to remove system audio bleed
- Configurable ducking levels (min/mid/max)

**HDR Recording (macOS 15+):**
- Uses `SCStreamConfiguration.captureHDRStreamLocalDisplay` preset
- Captures in BT.2100 PQ color space
- Exports screenshots with +1 EV adjustment for correct brightness

**Multi-track Audio (.qma):**
- Custom package format for separate system/mic audio tracks
- Contains `info.json` with format metadata and volume settings
- Allows independent mixing in `QmaPlayer`

**Pause/Resume:**
- Tracks cumulative time offset (`timeOffset`) across pause periods
- Adjusts CMTime timestamps via `adjustTime(sample:by:)` to maintain continuity

## Important File Paths

- **Main source:** `QuickRecorder/`
  - Core: `QuickRecorderApp.swift`, `RecordEngine.swift`, `SCContext.swift`, `AVContext.swift`
  - Views: `ViewModel/*.swift`
  - Utilities: `Supports/*.swift`
- **Entitlements:** `QuickRecorder/QuickRecorder.entitlements` (camera, microphone access)
- **Localization:** `Base.lproj/`, `zh-Hans.lproj/`, `zh-Hant.lproj/`, `it.lproj/`
- **Assets:** `QuickRecorder/Assets.xcassets/`

## Common Settings (@AppStorage keys)

Settings are stored in UserDefaults with `@AppStorage` wrappers:
- `encoder`: Video codec (h264/h265)
- `videoFormat`: Container format (mp4/mov)
- `audioFormat`: Audio codec (aac/alac/flac/opus/mp3)
- `frameRate`: Recording frame rate (default: 60)
- `videoQuality`: Quality multiplier (0.3/0.7/1.0)
- `highRes`: Retina scaling (2 = retina, 1 = non-retina)
- `recordWinSound`: Capture system audio
- `recordMic`: Capture microphone
- `remuxAudio`: Merge mic+system into single track
- `highlightMouse`: Show mouse highlight overlay
- `showMouse`: Include cursor in recording
- `background`: Window recording background (wallpaper/clear/solid colors)
- `saveDirectory`: Output folder path

## macOS Version Handling

The codebase targets multiple macOS versions with conditional compilation:
- `isMacOS12`, `isMacOS14`, `isMacOS15`: Global version flags
- `@available(macOS 14.0, *)`: Presenter overlay, `filter.pointPixelScale`
- `@available(macOS 15, *)`: HDR recording preset
- `#if compiler(>=6.0)`: Swift 6 specific features

When adding features, check version availability and provide fallbacks for older macOS versions.

## Permissions

QuickRecorder requires several system permissions:
- **Screen Recording**: Primary permission for ScreenCaptureKit (requested on first run)
- **Microphone**: Required if `recordMic` is enabled
- **Camera**: Required for camera overlay or device recording

Permission checks are in `SCContext.swift`:
- `requestPermissions()`: Screen recording (shows alert if denied)
- `performMicCheck()`: Microphone (async check)
- `requestCameraPermission()`: Camera access

## Known Limitations

- Not a sandboxed app (no App Store distribution planned)
- H.264 hardware encoder has resolution limitations (prompts to switch to H.265 if unsupported)
- macOS 12 doesn't support: system audio capture (`recordWinSound`), preview window
- Some features (presenter overlay, HDR) require newer macOS versions
