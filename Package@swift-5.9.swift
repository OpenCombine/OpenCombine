// swift-tools-version:5.9

import Foundation
import PackageDescription

// This list should be updated whenever SwiftPM adds support for a new platform.
// See: https://bugs.swift.org/browse/SR-13814
let supportedPlatforms: [Platform] = [
    .macOS,
    .macCatalyst,
    .iOS,
    .watchOS,
    .tvOS,
    .driverKit,
    .linux,
    .android,
    .windows,
    .wasi,
    .visionOS,
]

let openCombineTarget: Target = .target(
    name: "OpenCombine",
    dependencies: [
        .target(
            name: "COpenCombineHelpers",
            condition: .when(platforms: supportedPlatforms.except([.wasi]))
        ),
    ],
    exclude: [
        "Concurrency/Publisher+Concurrency.swift.gyb",
        "Publishers/Publishers.Encode.swift.gyb",
        "Publishers/Publishers.MapKeyPath.swift.gyb",
        "Publishers/Publishers.Catch.swift.gyb",
    ]
)
let openCombineFoundationTarget: Target = .target(
    name: "OpenCombineFoundation",
    dependencies: [
        "OpenCombine",
        .target(
            name: "COpenCombineHelpers",
            condition: .when(platforms: supportedPlatforms.except([.wasi]))
        ),
    ]
)
let openCombineDispatchTarget: Target = .target(
    name: "OpenCombineDispatch",
    dependencies: ["OpenCombine"]
)

let openCombineTestsTarget: Target = .testTarget(
    name: "OpenCombineTests",
    dependencies: [
        "OpenCombine",
        .target(name: "OpenCombineDispatch",
                condition: .when(platforms: supportedPlatforms.except([.wasi]))),
        .target(name: "OpenCombineFoundation",
                condition: .when(platforms: supportedPlatforms.except([.wasi]))),
    ],
    swiftSettings: [
        .unsafeFlags(["-enable-testing"]),
    ]
)

let package = Package(
    name: "OpenCombine",
    products: [
        .library(name: "OpenCombine",targets: ["OpenCombine"]),
        .library(name: "OpenCombineDispatch", targets: ["OpenCombineDispatch"]),
        .library(name: "OpenCombineFoundation", targets: ["OpenCombineFoundation"]),
        .library(name: "OpenCombineShim", targets: ["OpenCombineShim"]),
    ],
    targets: [
        .target(name: "COpenCombineHelpers"),
        .target(
            name: "OpenCombineShim",
            dependencies: [
                "OpenCombine",
                .target(name: "OpenCombineDispatch",
                        condition: .when(platforms: supportedPlatforms.except([.wasi]))),
                .target(name: "OpenCombineFoundation",
                        condition: .when(platforms: supportedPlatforms.except([.wasi]))),
            ]
        ),
        openCombineTarget,
        openCombineFoundationTarget,
        openCombineDispatchTarget,
        openCombineTestsTarget,
    ],
    cxxLanguageStandard: .cxx17
)

// MARK: Helpers

extension [Platform] {
    func except(_ exceptions: [Platform]) -> [Platform] {
        filter { !exceptions.contains($0) }
    }
}

func envEnable(_ key: String) -> Bool {
    guard let value = ProcessInfo.processInfo.environment[key] else {
        return false
    }
    return value == "1"
}

let enableLibraryEvolution = envEnable("OPENCOMBINE_LIBRARY_EVOLUTION")
if enableLibraryEvolution {
    let libraryEvolutionSetting: SwiftSetting = .unsafeFlags([
        "-Xfrontend", "-enable-library-evolution",
    ])
    let targets = [openCombineTarget, openCombineFoundationTarget, openCombineDispatchTarget]
    for target in targets {
        var settings = target.swiftSettings ?? []
        settings.append(libraryEvolutionSetting)
        target.swiftSettings = settings
    }
}

let enableCompatibilityTest = envEnable("OPENCOMBINE_COMPATIBILITY_TEST")
if enableCompatibilityTest {
    var settings = openCombineTestsTarget.swiftSettings ?? []
    settings.append(.define("OPENCOMBINE_COMPATIBILITY_TEST"))
    openCombineTestsTarget.swiftSettings = settings
}
