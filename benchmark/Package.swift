// swift-tools-version:5.0

import PackageDescription

//===---
// Single Source Libraries
//

var testCases = [String]()

testCases.append("CombineIdentifierCreation")
testCases.append("DeepMap")
testCases.append("PassthroughSubject_SendValue")
testCases.append("SequenceDelivery")

//===---
// Products
//

var products: [Product] = []

products.append(.library(name: "TestsUtils", type: .static, targets: ["TestsUtils"]))
products.append(.library(name: "DriverUtils", type: .static, targets: ["DriverUtils"]))
products.append(.executable(name: "OpenCombineBench", targets: ["OpenCombineBench"]))

products += testCases.map { .library(name: $0, type: .static, targets: [$0]) }

//===---
// Targets
//

var targets: [Target] = []
targets.append(.target(name: "TestsUtils", path: "utils", sources: ["TestsUtils.swift"]))
targets.append(.systemLibrary(name: "LibProc", path: "utils/LibProc"))
targets.append(
    .target(name: "DriverUtils",
            dependencies: [.target(name: "TestsUtils"), "LibProc"],
            path: "utils",
            sources: ["DriverUtils.swift", "ArgParse.swift"]))

var swiftBenchDeps: [Target.Dependency] = [.target(name: "TestsUtils")]

swiftBenchDeps.append(.target(name: "DriverUtils"))
swiftBenchDeps += testCases.map { .target(name: $0) }

targets.append(
    .target(name: "OpenCombineBench",
            dependencies: swiftBenchDeps,
            path: "utils",
            sources: ["main.swift"])
)

targets += testCases.map { name in
    .target(name: name,
            dependencies: ["OpenCombine", "CombineX", "TestsUtils"],
            path: "test-cases",
            sources: ["GENERATED-\(name).swift"])
}

//===---
// Top Level Definition
//

let p = Package.init(
    name: "OpenCombineBenchmark",
    platforms: [.macOS("10.15"), .iOS("13.0")],
    products: products,
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/cx-org/CombineX.git", .branch("master"))
    ],
    targets: targets
)
