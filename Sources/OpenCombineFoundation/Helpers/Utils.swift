//
//  Utils.swift
//
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

extension Optional {
    internal mutating func take() -> Optional {
        let taken = self
        self = nil
        return taken
    }
}
