// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "OpenCombine",
    products: [
        .library(name: "OpenCombine", targets: ["OpenCombine"]),
        .library(name: "OpenCombineDispatch", targets: ["OpenCombineDispatch"]),
    ],
    targets: [
        .target(name: "COpenCombineHelpers"),
        .target(name: "OpenCombine", dependencies: ["COpenCombineHelpers"]),
        .target(name: "OpenCombineDispatch", dependencies: ["OpenCombine"]),
        .target(name: "OpenCombineFoundation", dependencies: ["OpenCombine",
                                                              "COpenCombineHelpers"]),
        .testTarget(name: "OpenCombineTests",
                    dependencies: ["OpenCombine",
                                   "OpenCombineDispatch",
                                   "OpenCombineFoundation"],
                    swiftSettings: [.unsafeFlags(["-enable-testing"])])
    ],
    cxxLanguageStandard: .cxx1z
)
