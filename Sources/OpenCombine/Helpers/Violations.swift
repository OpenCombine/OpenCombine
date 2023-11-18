//
//  Violations.swift
//  
//
//  Created by Sergej Jaskiewicz on 16/09/2019.
//

internal func APIViolationValueBeforeSubscription(file: StaticString = #file,
                                                  line: UInt = #line) -> Never {
    fatalError("""
               API Violation: received an unexpected value before receiving a Subscription
               """,
               file: file,
               line: line)
}

internal func APIViolationUnexpectedCompletion(file: StaticString = #file,
                                               line: UInt = #line) -> Never {
    fatalError("API Violation: received an unexpected completion", file: file, line: line)
}

internal func abstractMethod(file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError("Abstract method call", file: file, line: line)
}

extension Subscribers.Demand {
    @_transparent
    @inline(__always)
    internal func assertNonZero() {
        precondition(rawValue <= 0x8000_0000_0000_0000)
        precondition(rawValue > 0)
    }
}
