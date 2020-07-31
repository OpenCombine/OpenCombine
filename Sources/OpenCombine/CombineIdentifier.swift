//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

public struct CombineIdentifier: Hashable, CustomStringConvertible {

    private let rawValue: UInt64

    public init() {
        rawValue = __nextCombineIdentifier()
    }

    public init(_ obj: AnyObject) {
        rawValue = UInt64(UInt(bitPattern: ObjectIdentifier(obj)))
    }

    public var description: String {
        return "0x\(String(rawValue, radix: 16))"
    }
}
