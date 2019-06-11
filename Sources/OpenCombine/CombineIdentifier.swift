//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public struct CombineIdentifier : Hashable, CustomStringConvertible {

    private let _id: UInt

    public init() {
        _id = 0
    }

    public init(_ obj: AnyObject) {
        _id = UInt(bitPattern: ObjectIdentifier(obj))
    }

    public var description: String {
        String(_id, radix: 16)
    }
}
