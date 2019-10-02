//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

import func COpenCombineHelpers.opencombine_next_combine_identifier

public struct CombineIdentifier: Hashable, CustomStringConvertible {

    private let id: UInt

    public init() {
        self.id = opencombine_next_combine_identifier()
    }

    public init(_ obj: AnyObject) {
        id = UInt(bitPattern: ObjectIdentifier(obj))
    }

    public var description: String {
        return "0x\(String(id, radix: 16))"
    }
}
