//
//  Utils.swift
//
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

internal protocol HasDefaultValue {
    init()
}

extension HasDefaultValue {

    @inline(__always)
    internal mutating func take() -> Self {
        let taken = self
        self = .init()
        return taken
    }
}

extension Array: HasDefaultValue {}

extension Dictionary: HasDefaultValue {}

extension Optional: HasDefaultValue {
    init() {
        self = nil
    }
}
