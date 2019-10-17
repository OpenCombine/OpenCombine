//===--- main.swift -------------------------------------------*- swift -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// This is just a driver for performance overview tests.

import TestsUtils
import DriverUtils

import CombineIdentifierCreation
import DeepMap
import PassthroughSubject_SendValue
import SequenceDelivery

@inline(__always)
private func registerBenchmark(_ bench: BenchmarkInfo) {
  registeredBenchmarks.append(bench)
}

@inline(__always)
private func registerBenchmark<
  S : Sequence
>(_ infos: S) where S.Element == BenchmarkInfo {
  registeredBenchmarks.append(contentsOf: infos)
}

registerBenchmark(CombineIdentifierCreation)
registerBenchmark(DeepMap)
registerBenchmark(PassthroughSubject_SendValue)
registerBenchmark(SequenceDelivery)

main()
