//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

#if canImport(COpenCombineHelpers)
@_implementationOnly import COpenCombineHelpers
#endif

#if os(WASI)
private var __identifier: UInt64 = 0

internal func __nextCombineIdentifier() -> UInt64 {
    defer { __identifier += 1 }
    return __identifier
}
#endif // os(WASI)

/// A unique identifier for identifying publisher streams.
///
/// To conform to `CustomCombineIdentifierConvertible` in a
/// `Subscription` or `Subject` that you implement as a structure, create an instance of
/// `CombineIdentifier` as follows:
///
///     let combineIdentifier = CombineIdentifier()
public struct CombineIdentifier: Hashable, CustomStringConvertible {

    private let rawValue: UInt64

    /// Creates a unique Combine identifier.
    public init() {
        rawValue = __nextCombineIdentifier()
    }

    /// Creates a Combine identifier, using the bit pattern of the provided object.
    public init(_ obj: AnyObject) {
        rawValue = UInt64(UInt(bitPattern: ObjectIdentifier(obj)))
    }

    public var description: String {
        return "0x\(String(rawValue, radix: 16))"
    }
}
