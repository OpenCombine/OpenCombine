//
//  {name}.swift
//
//

import OpenCombine
import CombineX

#if canImport(Combine)
import Combine
#endif

import TestsUtils

private let {name}_OpenCombine =
    BenchmarkInfo(name: "{name}_OpenCombine",
                  runFunction: run_{name}_OpenCombine,
                  tags: [.validation, .api])

private let {name}_CombineX =
    BenchmarkInfo(name: "{name}_CombineX",
                  runFunction: run_{name}_CombineX,
                  tags: [.validation, .api])

#if canImport(Combine)
private let {name}_Combine =
    BenchmarkInfo(name: "{name}_Combine",
                  runFunction: run_{name}_Combine,
                  tags: [.validation, .api])

public let {name} = [{name}_OpenCombine,
                     {name}_CombineX,
                     {name}_Combine]
#else
public let {name} = [{name}_OpenCombine,
                     {name}_CombineX]
#endif

let factor = 10000

@inline(never)
public func run_{name}_OpenCombine(N: Int) {{
    for _ in 1...factor*N {{
        // TODO
    }}
}}

@inline(never)
public func run_{name}_CombineX(N: Int) {{
    for _ in 1...factor*N {{
        // TODO
    }}
}}

#if canImport(Combine)

@inline(never)
public func run_{name}_Combine(N: Int) {{
    for _ in 1...factor*N {{
        // TODO
    }}
}}

#endif
