// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

import OpenCombine
import CombineX

#if canImport(Combine)
import Combine
#endif

import TestsUtils

private let CombineIdentifierCreation_OpenCombine =
    BenchmarkInfo(name: "CombineIdentifierCreation_OpenCombine",
                  runFunction: run_CombineIdentifierCreation_OpenCombine,
                  tags: [.validation, .api])

private let CombineIdentifierCreation_CombineX =
    BenchmarkInfo(name: "CombineIdentifierCreation_CombineX",
                  runFunction: run_CombineIdentifierCreation_CombineX,
                  tags: [.validation, .api])
#if canImport(Combine)
private let CombineIdentifierCreation_Combine =
    BenchmarkInfo(name: "CombineIdentifierCreation_Combine",
                  runFunction: run_CombineIdentifierCreation_Combine,
                  tags: [.validation, .api])
#endif
public var CombineIdentifierCreation: [BenchmarkInfo] {
    var tests = [BenchmarkInfo]()

    tests.append(CombineIdentifierCreation_OpenCombine)

    tests.append(CombineIdentifierCreation_CombineX)
#if canImport(Combine)
    tests.append(CombineIdentifierCreation_Combine)
#endif
    return tests
}

let factor = 10000

@inline(never)
public func run_CombineIdentifierCreation_OpenCombine(N: Int) {
    for _ in 1...(factor * N) {
        blackHole(OpenCombine.CombineIdentifier())
    }
}


@inline(never)
public func run_CombineIdentifierCreation_CombineX(N: Int) {
    for _ in 1...(factor * N) {
        blackHole(CombineX.CombineIdentifier())
    }
}

#if canImport(Combine)
@inline(never)
public func run_CombineIdentifierCreation_Combine(N: Int) {
    for _ in 1...(factor * N) {
        blackHole(Combine.CombineIdentifier())
    }
}
#endif
