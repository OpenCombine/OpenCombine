//
//  XCTUnwrap.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

import XCTest

// XCTUnwrap is not available when using Swift Package Manager.
// This has been fixed in Swift 5.2, but we want to maintain compatibility.
#if swift(<5.2)

private struct UnwrappingFailure: Error, LocalizedError {

    let message: String

    var errorDescription: String? {
        var failureDescription = "XCTUnwrap failed"
        if !message.isEmpty {
            failureDescription += ": "
            failureDescription += message
        }
        return failureDescription
    }
}

/// Asserts that an expression is not `nil`, and returns its unwrapped value.
///
/// Generates a failure when `expression == nil`.
///
/// - Parameters:
///   - expression: An expression of type `T?` to compare against `nil`. Its type will
///     determine the type of the returned value.
///   - message: An optional description of the failure.
///   - file: The file in which failure occurred. Defaults to the file name of the test
///     case in which this function was called.
///   - line: The line number on which failure occurred. Defaults to the line number on
///     which this function was called.
/// - Returns: A value of type `T`, the result of evaluating and unwrapping the given
///   `expression`.
/// - Throws: An error when `expression == nil`. It will also rethrow any error thrown
///   while evaluating the given expression.
public func XCTUnwrap<Result>(_ expression: @autoclosure () throws -> Result?,
                              _ message: @autoclosure () -> String = "",
                              file: StaticString = #file,
                              line: UInt = #line) throws -> Result {
    let result = try expression()
    if let result = result {
        return result
    } else {
        let error = UnwrappingFailure(message: message())
        XCTFail(error.errorDescription ?? "", file: file, line: line)
        throw error
    }
}
#endif
