//
//  TestingError.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import Foundation

struct TestingError: Error, Hashable, CustomStringConvertible {
    let description: String

    static func == (lhs: TestingError, rhs: String) -> Bool {
        lhs.description == rhs
    }

    static func == (lhs: String, rhs: TestingError) -> Bool {
        lhs == rhs.description
    }

    static func != (lhs: TestingError, rhs: String) -> Bool {
        !(lhs == rhs)
    }

    static func != (lhs: String, rhs: TestingError) -> Bool {
        !(lhs == rhs)
    }
}

extension TestingError: LocalizedError {
    var errorDescription: String? { description }
}

extension TestingError: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(description: value)
    }
}
