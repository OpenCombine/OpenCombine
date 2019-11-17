//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

import func COpenCombineHelpers.nextCombineIdentifier

public struct CombineIdentifier: Hashable, CustomStringConvertible {

    private let value: UInt64

    public init() {
        value = nextCombineIdentifier()
    }

    public init(_ obj: AnyObject) {
        value = UInt64(UInt(bitPattern: ObjectIdentifier(obj)))
    }

    public var description: String {
        return "0x\(String(value, radix: 16))"
    }
}
