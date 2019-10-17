//
//  CombineIdentifierCreation.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.10.2019.
//

import OpenCombine
import CombineX

#if canImport(Combine)
import Combine
#endif

import TestsUtils

let CombineIdentifierCreation_OpenCombine =
    BenchmarkInfo(name: "CombineIdentifierCreation_OpenCombine",
                  runFunction: run_CombineIdentifierCreation_OpenCombine,
                  tags: [.validation, .api])

let CombineIdentifierCreation_CombineX =
    BenchmarkInfo(name: "CombineIdentifierCreation_CombineX",
                  runFunction: run_CombineIdentifierCreation_CombineX,
                  tags: [.validation, .api])

#if canImport(Combine)
let CombineIdentifierCreation_Combine =
    BenchmarkInfo(name: "CombineIdentifierCreation_Combine",
                  runFunction: run_CombineIdentifierCreation_Combine,
                  tags: [.validation, .api])

public let CombineIdentifierCreation = [CombineIdentifierCreation_OpenCombine,
                                        CombineIdentifierCreation_CombineX,
                                        CombineIdentifierCreation_Combine]
#else
public let CombineIdentifierCreation = [CombineIdentifierCreation_OpenCombine,
                                        CombineIdentifierCreation_CombineX]
#endif

let factor = 10000

@inline(never)
public func run_CombineIdentifierCreation_OpenCombine(N: Int) {
    for _ in 1...factor*N {
        blackHole(OpenCombine.CombineIdentifier())
    }
}

@inline(never)
public func run_CombineIdentifierCreation_CombineX(N: Int) {
    for _ in 1...factor*N {
        blackHole(CombineX.CombineIdentifier())
    }
}

#if canImport(Combine)

@inline(never)
public func run_CombineIdentifierCreation_Combine(N: Int) {
    for _ in 1...factor*N {
        blackHole(Combine.CombineIdentifier())
    }
}

#endif
