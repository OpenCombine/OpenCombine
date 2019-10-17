//
//  PassthroughSubject_SendValue.swift
//
//

import OpenCombine
import CombineX

#if canImport(Combine)
import Combine
#endif

import TestsUtils

private let PassthroughSubject_SendValue_OpenCombine =
    BenchmarkInfo(name: "PassthroughSubject_SendValue_OpenCombine",
                  runFunction: run_PassthroughSubject_SendValue_OpenCombine,
                  tags: [.validation, .api])

private let PassthroughSubject_SendValue_CombineX =
    BenchmarkInfo(name: "PassthroughSubject_SendValue_CombineX",
                  runFunction: run_PassthroughSubject_SendValue_CombineX,
                  tags: [.validation, .api])

#if canImport(Combine)
private let PassthroughSubject_SendValue_Combine =
    BenchmarkInfo(name: "PassthroughSubject_SendValue_Combine",
                  runFunction: run_PassthroughSubject_SendValue_Combine,
                  tags: [.validation, .api])

public let PassthroughSubject_SendValue = [PassthroughSubject_SendValue_OpenCombine,
                                           PassthroughSubject_SendValue_CombineX,
                                           PassthroughSubject_SendValue_Combine]
#else
public let PassthroughSubject_SendValue = [PassthroughSubject_SendValue_OpenCombine,
                                           PassthroughSubject_SendValue_CombineX]
#endif

let factor = 10000

@inline(never)
public func run_PassthroughSubject_SendValue_OpenCombine(N: Int) {
    let subject = OpenCombine.PassthroughSubject<Int, Never>()
    var counter = 0

    let cancellable = subject.sink {
        counter += $0
    }

    let sequenceLength = factor * N

    withExtendedLifetime(cancellable) {
        for i in 1...sequenceLength {
            subject.send(i)
        }
    }

    CheckResults(counter == sequenceLength * (sequenceLength + 1) / 2)
}

@inline(never)
public func run_PassthroughSubject_SendValue_CombineX(N: Int) {
    let subject = CombineX.PassthroughSubject<Int, Never>()
    var counter = 0

    let cancellable = subject.sink {
        counter += $0
    }

    let sequenceLength = factor * N

    withExtendedLifetime(cancellable) {
        for i in 1...sequenceLength {
            subject.send(i)
        }
    }

    CheckResults(counter == sequenceLength * (sequenceLength + 1) / 2)
}

#if canImport(Combine)

@inline(never)
public func run_PassthroughSubject_SendValue_Combine(N: Int) {
    let subject = Combine.PassthroughSubject<Int, Never>()
    var counter = 0

    let cancellable = subject.sink {
        counter += $0
    }

    let sequenceLength = factor * N

    withExtendedLifetime(cancellable) {
        for i in 1...sequenceLength {
            subject.send(i)
        }
    }

    CheckResults(counter == sequenceLength * (sequenceLength + 1) / 2)
}

#endif
