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

private let DeepMap_OpenCombine =
    BenchmarkInfo(name: "DeepMap_OpenCombine",
                  runFunction: run_DeepMap_OpenCombine,
                  tags: [.validation, .api])

private let DeepMap_CombineX =
    BenchmarkInfo(name: "DeepMap_CombineX",
                  runFunction: run_DeepMap_CombineX,
                  tags: [.validation, .api])
#if canImport(Combine)
private let DeepMap_Combine =
    BenchmarkInfo(name: "DeepMap_Combine",
                  runFunction: run_DeepMap_Combine,
                  tags: [.validation, .api])
#endif
public var DeepMap: [BenchmarkInfo] {
    var tests = [BenchmarkInfo]()

    tests.append(DeepMap_OpenCombine)

    tests.append(DeepMap_CombineX)
#if canImport(Combine)
    tests.append(DeepMap_Combine)
#endif
    return tests
}

let factor = 10000

@inline(never)
public func run_DeepMap_OpenCombine(N: Int) {
    let sequenceLength = 1_000 * N
    let subject = OpenCombine.PassthroughSubject<Int, Never>()

    var counter = 0
    let cancellable = subject
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .sink { value in
            counter += value
        }

    withExtendedLifetime(cancellable) {
        for i in 1...sequenceLength {
            subject.send(i)
        }
    }

}


@inline(never)
public func run_DeepMap_CombineX(N: Int) {
    let sequenceLength = 1_000 * N
    let subject = CombineX.PassthroughSubject<Int, Never>()

    var counter = 0
    let cancellable = subject
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .sink { value in
            counter += value
        }

    withExtendedLifetime(cancellable) {
        for i in 1...sequenceLength {
            subject.send(i)
        }
    }

}

#if canImport(Combine)
@inline(never)
public func run_DeepMap_Combine(N: Int) {
    let sequenceLength = 1_000 * N
    let subject = Combine.PassthroughSubject<Int, Never>()

    var counter = 0
    let cancellable = subject
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .map { $0 }
        .sink { value in
            counter += value
        }

    withExtendedLifetime(cancellable) {
        for i in 1...sequenceLength {
            subject.send(i)
        }
    }

}
#endif
