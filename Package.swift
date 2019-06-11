// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "OpenCombine",
    products: [
        .library(name: "OpenCombine", targets: ["OpenCombine"]),
    ],
    targets: [
        .target(name: "OpenCombine"),
        .testTarget(name: "OpenCombineTests", dependencies: ["OpenCombine"])
    ]
)
