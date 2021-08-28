// swift-tools-version:5.4

import PackageDescription

// This list should be updated whenever SwiftPM adds support for a new platform.
// See: https://bugs.swift.org/browse/SR-13814
let supportedPlatforms: [Platform] = [
    .macOS,
    .iOS,
    .watchOS,
    .tvOS,
    .linux,
    .android,
    .windows,
    .wasi,
]

let package = Package(
    name: "OpenCombine",
    products: [
        .library(name: "OpenCombine", targets: ["OpenCombine"]),
        .library(name: "OpenCombineDispatch", targets: ["OpenCombineDispatch"]),
        .library(name: "OpenCombineFoundation", targets: ["OpenCombineFoundation"]),
        .library(name: "OpenCombineShim", targets: ["OpenCombineShim"]),
    ],
    targets: [
        .target(name: "COpenCombineHelpers"),
        .target(
            name: "OpenCombine",
            dependencies: [
                .target(name: "COpenCombineHelpers",
                        condition: .when(platforms: supportedPlatforms.except([.wasi])))
            ],
            exclude: [
                "Concurrency/Publisher+Concurrency.swift.gyb",
                "Publishers/Publishers.Encode.swift.gyb",
                "Publishers/Publishers.MapKeyPath.swift.gyb",
                "Publishers/Publishers.Catch.swift.gyb"
            ],
            swiftSettings: [.define("WASI", .when(platforms: [.wasi]))]
        ),
        .target(name: "OpenCombineDispatch", dependencies: ["OpenCombine"]),
        .target(
            name: "OpenCombineFoundation",
            dependencies: [
                "OpenCombine",
                .target(name: "COpenCombineHelpers",
                        condition: .when(platforms: supportedPlatforms.except([.wasi])))
            ]
        ),
        .target(
            name: "OpenCombineShim",
            dependencies: [
                "OpenCombine",
                .target(name: "OpenCombineDispatch",
                        condition: .when(platforms: supportedPlatforms.except([.wasi]))),
                .target(name: "OpenCombineFoundation",
                        condition: .when(platforms: supportedPlatforms.except([.wasi])))
            ]
        ),
        .testTarget(
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
                .define("WASI", .when(platforms: [.wasi]))
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)

// MARK: Helpers

extension Array where Element == Platform {
    func except(_ exceptions: [Platform]) -> [Platform] {
        // See: https://bugs.swift.org/browse/SR-13813
        let exceptionsDescriptions = exceptions.map(String.init(describing:))
        return filter { platform in
            !exceptionsDescriptions.contains(String(describing: platform))
        }
    }
}
