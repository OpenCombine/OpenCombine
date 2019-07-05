// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "OpenCombine",
    products: [
        .library(name: "OpenCombine", targets: ["OpenCombine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/broadwaylamb/GottaGoFast.git", from: "0.1.0")
    ],
    targets: [
        .target(name: "OpenCombine"),
        .testTarget(name: "OpenCombineTests",
                    dependencies: ["OpenCombine", "GottaGoFast"])
    ]
)
