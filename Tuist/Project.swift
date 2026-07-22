// Project.swift
// Tuist project definition for GuitarTuner - iOS/macOS guitar tuner app

import ProjectDescription

let name = "GuitarTuner"
let bundleIdPrefix = "com.dyldog"
let deploymentTarget: DeploymentTargets = .iOS("16.0")
let macDeploymentTarget: DeploymentTargets = .macOS("13.0")
let swiftVersion = "5.9"

let project = Project(
    name: name,
    organizationName: "Dyldog",
    options: .options(
        automaticSchemesOptions: .enabled(
            targetSchemesGrouping: .byNameSuffix,
            codeCoverageEnabled: true,
            testingOptions: [.parallelizable, .randomExecutionOrdering]
        ),
        textSettings: .textSettings(usesTabs: false, indentWidth: 4)
    ),
    settings: .settings(
        base: [
            "SWIFT_VERSION": swiftVersion,
            "ENABLE_HARDENED_RUNTIME": "YES",
            "CODE_SIGN_STYLE": "Automatic",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME": "AccentColor",
            "GENERATE_INFOPLIST_FILE": "NO",
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
        // Shared framework target (shared SwiftUI code)
        Target.target(
            name: "\(name)Shared",
            destinations: [.iPhone, .iPad, .mac],
            product: .framework,
            bundleId: "\(bundleIdPrefix).\(name)Shared",
            deploymentTargets: .iOS("16.0"),
            infoPlist: .default,
            sources: ["../../Shared/Sources/**"],
            resources: ["../../Shared/Resources/**"],
            dependencies: []
        ),
        
        // macOS app target
        Target.target(
            name: name,
            destinations: [.mac],
            product: .app,
            bundleId: "\(bundleIdPrefix).\(name)",
            deploymentTargets: macDeploymentTarget,
            infoPlist: .file(path: "../../MacApp/Resources/Info.plist"),
            sources: [
                "../../MacApp/Sources/**",
                "../../Shared/Sources/**",
            ],
            resources: [
                "../../MacApp/Resources/**",
                "../../Shared/Resources/**",
            ],
            entitlements: .file(path: "../../MacApp/Resources/GuitarTuner.entitlements"),
            dependencies: [
                .target(name: "\(name)Shared"),
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "MacApp/Resources/Info.plist",
                    "CODE_SIGN_ENTITLEMENTS": "MacApp/Resources/GuitarTuner.entitlements",
                    "MACOSX_DEPLOYMENT_TARGET": "13.0",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME": "AccentColor",
                ]
            )
        ),
        
        // iOS app target
        Target.target(
            name: "\(name)-iOS",
            destinations: [.iPhone, .iPad],
            product: .app,
            bundleId: "\(bundleIdPrefix).\(name)",
            deploymentTargets: deploymentTarget,
            infoPlist: .file(path: "../../iOSApp/Resources/Info.plist"),
            sources: [
                "../../iOSApp/Sources/**",
                "../../Shared/Sources/**",
            ],
            resources: [
                "../../iOSApp/Resources/**",
                "../../Shared/Resources/**",
            ],
            entitlements: .file(path: "../../iOSApp/Resources/GuitarTuner.entitlements"),
            dependencies: [
                .target(name: "\(name)Shared"),
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "iOSApp/Resources/Info.plist",
                    "CODE_SIGN_ENTITLEMENTS": "iOSApp/Resources/GuitarTuner.entitlements",
                    "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
                    "TARGETED_DEVICE_FAMILY": "1,2",
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME": "AccentColor",
                ]
            )
        ),
        
        // macOS Unit Tests
        Target.target(
            name: "\(name)Tests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(name)Tests",
            deploymentTargets: macDeploymentTarget,
            infoPlist: .default,
            sources: ["../../MacApp/Tests/**"],
            dependencies: [
                .target(name: name),
            ]
        ),
        
        // iOS Unit Tests
        Target.target(
            name: "\(name)-iOSTests",
            destinations: [.iPhone, .iPad],
            product: .unitTests,
            bundleId: "\(bundleIdPrefix).\(name)Tests",
            deploymentTargets: deploymentTarget,
            infoPlist: .default,
            sources: ["../../iOSApp/Tests/**"],
            dependencies: [
                .target(name: "\(name)-iOS"),
            ]
        ),
    ],
    schemes: [
        Scheme.scheme(
            name: name,
            shared: true,
            buildAction: .buildAction(targets: [.target(name)]),
            testAction: .targets([.target(name: "\(name)Tests")]),
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
            buildAction: .buildAction(targets: [.target(name: "\(name)-iOS")]),
            testAction: .targets([.target(name: "\(name)-iOSTests")]),
            runAction: .runAction(
                configuration: .debug,
                executable: .target(name: "\(name)-iOS")
            ),
            archiveAction: .archiveAction(configuration: .release),
            profileAction: .profileAction(configuration: .release),
            analyzeAction: .analyzeAction(configuration: .debug)
        ),
    ]
)