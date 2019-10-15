//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

import func COpenCombineHelpers.nextCombineIdentifier

public struct CombineIdentifier: Hashable, CustomStringConvertible {

    private let id: UInt64

    public init() {
        self.id = nextCombineIdentifier()
    }

    public init(_ obj: AnyObject) {
        id = UInt64(UInt(bitPattern: ObjectIdentifier(obj)))
    }

    public var description: String {
        return "0x\(String(id, radix: 16))"
    }
}
