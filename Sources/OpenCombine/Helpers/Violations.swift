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

@inline(__always)
internal func abstractMethod(file: StaticString = #file, line: UInt = #line) -> Never {
    unreachable("Abstract method call", file: file, line: line)
}

extension Subscribers.Demand {
    internal func assertNonZero(file: StaticString = #file,
                                line: UInt = #line) {
        if self == .none {
            fatalError("API Violation: demand must not be zero", file: file, line: line)
        }
    }
}
