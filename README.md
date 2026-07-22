# GuitarTuner

A precision guitar tuner app for iOS and macOS built with SwiftUI and Tuist.

## Features

- **Real-time pitch detection** using autocorrelation-based algorithm
- **Multiple tuning presets**: Standard, Drop D, Drop C, Open G, Open D, DADGAD, Half Step Down
- **Visual tuning meter** with cents accuracy (±1¢ precision)
- **Per-string indicators** showing target frequency and tuning status
- **Calibration adjustment** (A4 = 415-466 Hz)
- **Microphone-based input** with permission handling
- **Dark mode optimized** UI with gradient accents
- **Shared SwiftUI codebase** for iOS and macOS

## Requirements

- macOS 13.0+ (Ventura)
- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- Tuist 4.0+

## Project Structure

```
GuitarTuner/
├── Tuist/                  # Tuist project configuration
│   ├── Config.swift        # Tuist config (Xcode version, Swift version)
│   └── Project.swift       # Project definition (targets, schemes, settings)
├── Shared/                 # Shared SwiftUI code (framework target)
│   └── Sources/
│       ├── GuitarTunerShared.swift  # Models, tuner engine, pitch detector
│       └── TunerView.swift          # Main UI views
├── MacApp/                 # macOS app target
│   ├── Sources/
│   │   └── GuitarTunerMacApp.swift  # macOS app entry point
│   └── Resources/
│       ├── Info.plist
│       ├── GuitarTuner.entitlements
│       └── Assets.xcassets/
├── iOSApp/                 # iOS app target
│   ├── Sources/
│   │   └── GuitarTuneriOSApp.swift  # iOS app entry point
│   └── Resources/
│       ├── Info.plist
│       ├── GuitarTuner.entitlements
│       └── Assets.xcassets/
├── scripts/                # Build & CI scripts
│   ├── build.sh            # Local build verification
│   ├── ci-build.sh         # CI build & archive
│   ├── bump-version.sh     # Version bumping
│   ├── testflight-upload.sh # TestFlight upload
│   └── export-options-*.plist # Export options for CI
└── .github/workflows/
    └── ci-build.yml        # GitHub Actions CI pipeline
```

## Quick Start

### 1. Install Tuist

```bash
curl -Ls https://install.tuist.io | bash
```

### 2. Generate Xcode Project

```bash
tuist generate
```

This creates `GuitarTuner.xcodeproj` in the project root.

### 3. Open in Xcode

```bash
open GuitarTuner.xcodeproj
```

### 4. Build & Run

- Select **GuitarTuner** scheme for macOS
- Select **GuitarTuner-iOS** scheme for iOS Simulator/Device
- Press ⌘R to build and run

## Local Build Verification

```bash
./scripts/build.sh
```

This runs `tuist generate` and builds both schemes.

## CI Pipeline

The GitHub Actions workflow (`.github/workflows/ci-build.yml`) runs on:
- Push to `main`
- Pull requests to `main`
- Manual dispatch

It builds both macOS and iOS schemes in parallel, archives signed builds when secrets are configured, and optionally uploads to TestFlight.

### Required Secrets for Signing

| Secret | Description |
|--------|-------------|
| `APPLE_CERT_P12_BASE64` | Distribution certificate (P12) base64 encoded |
| `APPLE_CERT_PASSWORD` | P12 password |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `IOS_PROVISIONING_PROFILE_BASE64` | iOS provisioning profile base64 |
| `MAC_PROVISIONING_PROFILE_BASE64` | macOS provisioning profile base64 |

### Required Secrets for TestFlight Upload

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | P8 private key base64 encoded |

## Architecture

### Shared Framework (`GuitarTunerShared`)

The core logic lives in a shared framework target used by both apps:

- **Models**: `GuitarString`, `TuningPreset`
- **Audio Engine**: `TunerEngine` (AVAudioEngine + pitch detection)
- **Pitch Detection**: Autocorrelation with parabolic interpolation
- **UI**: `TunerView`, `TuningMeterView`, `StringSelectorView`, `TuningPickerView`

### App Targets

- **GuitarTuner** (macOS): Window-based app with toolbar
- **GuitarTuner-iOS** (iOS): Full-screen window group

Both apps share 100% of the UI and logic through the framework.

## Pitch Detection Algorithm

The `PitchDetector` class uses autocorrelation with Hanning window:

1. Apply Hanning window to audio buffer
2. Compute autocorrelation for lags corresponding to 50-500 Hz
3. Find peak correlation lag
4. Parabolic interpolation for sub-sample accuracy
5. Convert lag to frequency: `f = sampleRate / lag`

Accuracy: ±1 cent for typical guitar frequencies (82-330 Hz).

## License

Copyright © 2024 Dyldog. All rights reserved.