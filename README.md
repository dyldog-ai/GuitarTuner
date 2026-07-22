# GuitarTuner — The Parlour Tuner

A precision guitar tuner for iOS and macOS built with SwiftUI and Tuist, styled
after a 19th-century parlour instrument: mahogany cabinet, engraved brass
plaque, and a galvanometer-style needle gauge on a parchment face.

## Features

- **Real-time pitch detection** using the McLeod Pitch Method (NSDF), resistant to the octave errors plucked-string harmonics cause in naive autocorrelation
- **Automatic string detection** — pluck any string and the matching brass peg lights up; no tapping or manual selection
- **Multiple tuning presets**: Standard, Drop D, Drop C, Open G, Open D, DADGAD, Half Step Down
- **Needle gauge** reading ±50 cents, with plain-language advice ("Wind the string tighter")
- **Microphone-based input** with permission handling
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
├── Tuist.swift             # Tuist config (Xcode version, Swift version)
├── Project.swift           # Project definition (targets, schemes, settings)
├── Shared/                 # Shared SwiftUI code
│   └── Sources/
│       └── GuitarTunerShared.swift  # Models, tuner engine, pitch detector, UI
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
- **Audio Engine**: `TunerEngine` (AVAudioEngine tap → pitch detection → smoothed, briefly-held readings)
- **Pitch Detection**: `PitchDetector` — McLeod Pitch Method with parabolic interpolation
- **View Model**: `TunerViewModel` — maps the detected pitch onto the nearest string of the selected tuning
- **UI**: `TunerView`, `ParlourGaugeView`, `StringPegsView`, `TuningPickerView`

### App Targets

- **GuitarTuner** (macOS): Window-based app with toolbar
- **GuitarTuner-iOS** (iOS): Full-screen window group

Both apps share 100% of the UI and logic through the framework.

## Pitch Detection Algorithm

The `PitchDetector` class implements the McLeod Pitch Method:

1. Gate on RMS amplitude to ignore background noise
2. Compute the normalized square difference function (NSDF) for lags corresponding to 55–500 Hz, using vDSP and prefix sums
3. Pick key maxima between zero crossings; take the first maximum above 90% of the global peak (this is what avoids octave errors)
4. Reject unclear signals (peak NSDF below 0.82)
5. Parabolic interpolation for sub-sample accuracy, then `f = sampleRate / lag`

The detector runs at the actual hardware sample rate reported by the input
node — assuming 44.1 kHz on 48 kHz hardware would read ~9% sharp. Readings are
median-smoothed over recent buffers and held briefly between plucks so the
needle doesn't flicker.

## License

Copyright © 2024 Dyldog. All rights reserved.