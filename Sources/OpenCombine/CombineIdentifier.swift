//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public struct CombineIdentifier : Hashable, CustomStringConvertible {

    private static var _counter: UInt = 0

    // FIXME: Use a common lock instead of recursive?
    private static let _counterLock = RecursiveLock()

    private let _id: UInt

    public init() {

        var id: UInt = 0

        Self._counterLock.do {
            id = Self._counter
            Self._counter += 1
        }

        _id = id
    }

    public init(_ obj: AnyObject) {
        _id = UInt(bitPattern: ObjectIdentifier(obj))
    }

    public var description: String {
        "0x\(String(_id, radix: 16))"
    }
}
