// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "OpenCombine",
    products: [
        .library(name: "OpenCombine", targets: ["OpenCombine"]),
        .library(name: "OpenCombineDispatch", targets: ["OpenCombineDispatch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/broadwaylamb/GottaGoFast.git", from: "0.1.0")
    ],
    targets: [
        .target(name: "OpenCombine"),
        .target(name: "OpenCombineDispatch", dependencies: ["OpenCombine"]),
        .testTarget(name: "OpenCombineTests",
                    dependencies: ["OpenCombine",
                                   "OpenCombineDispatch",
                                   "GottaGoFast"],
                    swiftSettings: [.unsafeFlags(["-enable-testing"])])
    ]
)
