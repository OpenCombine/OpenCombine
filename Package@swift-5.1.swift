// swift-tools-version:5.1

import PackageDescription

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
        .target(name: "OpenCombine", dependencies: ["COpenCombineHelpers"]),
        .target(name: "OpenCombineDispatch", dependencies: ["OpenCombine"]),
        .target(name: "OpenCombineFoundation", dependencies: ["OpenCombine",
                                                              "COpenCombineHelpers"]),
        .target(
            name: "OpenCombineShim",
            dependencies: [
                "OpenCombine",
                "OpenCombineDispatch",
                "OpenCombineFoundation",
            ]
        ),
        .testTarget(name: "OpenCombineTests",
                    dependencies: ["OpenCombine",
                                   "OpenCombineDispatch",
                                   "OpenCombineFoundation"],
                    swiftSettings: [.unsafeFlags(["-enable-testing"])])
    ],
    cxxLanguageStandard: .cxx1z
)
