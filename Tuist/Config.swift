// Tuist/Config.swift
// Tuist configuration

import ProjectDescription

let config = Config(
    project: .tuist(
        generationOptions: .options(
            resolveDependenciesWithSystemScm: false
        )
    )
)