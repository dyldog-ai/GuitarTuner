// Tuist/Config.swift
// Tuist configuration

import ProjectDescription

let config = Config(
    compatibleXcodeVersions: ">= 15.0",
    swiftVersion: "5.9",
    generationOptions: .options(
        enableNewBuildSystem: true,
        enableAutomaticXcodeSchemes: true,
        disableBundleAccessors: true
    ),
    options: .options(
        allowStaticProductsToAccessBundle: true,
        generateWorkspace: true
    )
)