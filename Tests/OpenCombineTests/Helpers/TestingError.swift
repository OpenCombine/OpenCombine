//
//  TestingError.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import Foundation
import XCTest

struct TestingError: Error, Hashable, Codable, CustomStringConvertible {
    let description: String

    static func == (lhs: TestingError, rhs: String) -> Bool {
        return lhs.description == rhs
    }

    static func == (lhs: String, rhs: TestingError) -> Bool {
        return lhs == rhs.description
    }

    static func != (lhs: TestingError, rhs: String) -> Bool {
        return !(lhs == rhs)
    }

    static func != (lhs: String, rhs: TestingError) -> Bool {
        return !(lhs == rhs)
    }

    static let oops: TestingError = "oops"
}

extension TestingError: LocalizedError {
    var errorDescription: String? { return description }
}

extension TestingError: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(description: value)
    }
}

protocol EquatableError: Error {
    func isEqual(_ other: EquatableError) -> Bool
}

extension EquatableError where Self: Equatable {
    func isEqual(_ other: EquatableError) -> Bool {
        return self == (other as? Self)
    }
}

extension TestingError: EquatableError {}

extension NSError: EquatableError {}

func assertThrowsError<Result>(_ expression: @autoclosure () throws -> Result,
                               _ expected: TestingError,
                               _ message: @autoclosure () -> String = "") {
    XCTAssertThrowsError(try expression(), message()) { error in
        if let error = error as? TestingError {
            XCTAssertEqual(error, expected)
        } else {
            XCTFail(message())
        }
    }
}

// swiftlint:disable:next generic_type_name
func throwing<A, B, C>(_: A, _: B) throws -> C {
    throw TestingError.oops
}

// swiftlint:disable:next generic_type_name
func throwing<A, B>(_: A) throws -> B {
    throw TestingError.oops
}
