//
//  CombineIdentifier.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

import COpenCombineAtomics

public struct CombineIdentifier: Hashable, CustomStringConvertible {

    private static let counter = opencombine_atomic_uintptr_t_create(0)

    private let id: UInt

    public init() {
        self.id = opencombine_atomic_uintptr_t_add(CombineIdentifier.counter, 1)
    }

    public init(_ obj: AnyObject) {
        id = UInt(bitPattern: ObjectIdentifier(obj))
    }

    public var description: String {
        return "0x\(String(id, radix: 16))"
    }
}
