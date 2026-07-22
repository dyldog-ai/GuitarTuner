// Project.swift
// Tuist project definition for GuitarTuner - iOS/macOS guitar tuner app

import ProjectDescription

let name = "GuitarTuner"
let bundleIdPrefix = "com.dyldog"
let iosDeploymentTarget: DeploymentTargets = .iOS("16.0")
let macDeploymentTarget: DeploymentTargets = .macOS("13.0")
let swiftVersion = "5.9"

let project = Project(
    name: name,
    organizationName: "Dyldog",
    options: .options(
        automaticSchemesOptions: .disabled,
        textSettings: .textSettings(usesTabs: false, indentWidth: 4)
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": .string(swiftVersion),
            "CODE_SIGN_STYLE": "Automatic",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME": "AccentColor",
        ],
        configurations: [
            .debug(name: "Debug", settings: [
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                "ENABLE_TESTABILITY": "YES",
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
            ]),
            .release(name: "Release", settings: [
                "SWIFT_OPTIMIZATION_LEVEL": "-O",
                "VALIDATE_PRODUCT": "YES",
            ]),
        ],
        defaultSettings: .recommended
    ),
    targets: [
        // macOS app target
        Target.target(
            name: name,
            destinations: [.mac],
            product: .app,
            bundleId: "\(bundleIdPrefix).\(name)",
            deploymentTargets: macDeploymentTarget,
            infoPlist: .file(path: "MacApp/Resources/Info.plist"),
            sources: [
                "MacApp/Sources/**",
                "Shared/Sources/**",
            ],
            resources: [
                "MacApp/Resources/Assets.xcassets",
            ],
            entitlements: .file(path: "MacApp/Resources/GuitarTuner.entitlements"),
            settings: .settings(
                base: [
                    "ENABLE_HARDENED_RUNTIME": "YES",
                    "MACOSX_DEPLOYMENT_TARGET": "13.0",
                ]
            )
        ),

        // iOS app target
        Target.target(
            name: "\(name)-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "\(bundleIdPrefix).\(name)",
            deploymentTargets: iosDeploymentTarget,
            infoPlist: .file(path: "iOSApp/Resources/Info.plist"),
            sources: [
                "iOSApp/Sources/**",
                "Shared/Sources/**",
            ],
            resources: [
                "iOSApp/Resources/Assets.xcassets",
            ],
            entitlements: .file(path: "iOSApp/Resources/GuitarTuner.entitlements"),
            settings: .settings(
                base: [
                    "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                    "TARGETED_DEVICE_FAMILY": "1,2",
                ]
            )
        ),
    ],
    schemes: [
        Scheme.scheme(
            name: name,
            shared: true,
            buildAction: .buildAction(targets: [.target(name)]),
            runAction: .runAction(
                configuration: .debug,
                executable: .target(name)
            ),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
        Scheme.scheme(
            name: "\(name)-iOS",
            shared: true,
            buildAction: .buildAction(targets: [.target("\(name)-iOS")]),
            runAction: .runAction(
                configuration: .debug,
                executable: .target("\(name)-iOS")
            ),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ]
)
