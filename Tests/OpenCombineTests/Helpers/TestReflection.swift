//
//  TestReflection.swift
//  
//
//  Created by Sergej Jaskiewicz on 21/09/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

let childrenIsEmpty: (Mirror) -> Bool = { $0.children.isEmpty }

enum ExpectedMirrorChildValue: ExpressibleByStringLiteral {
    case anything
    case matches(@autoclosure () -> String)
    case contains(@autoclosure () -> String)

    typealias StringLiteralType = String

    init(stringLiteral value: String) {
        self = .matches(value)
    }
}

@discardableResult
func expectedChildren(_ expectedChildren: (String?, ExpectedMirrorChildValue)...,
                      file: StaticString = #file,
                      line: UInt = #line) -> (Mirror) -> Bool {
    return { mirror in

        let actualChildren = mirror
            .children
            .map { ($0, String(describing: $1)) }

        XCTAssertEqual(actualChildren.count,
                       expectedChildren.count,
                       "The children collections are of different sizes",
                       file: file,
                       line: line)

        for (actualChild, expectedChild) in zip(actualChildren, expectedChildren) {
            XCTAssertEqual(actualChild.0, expectedChild.0, file: file, line: line)
            switch (actualChild.1, expectedChild.1) {
            case (_, .anything):
                continue
            case let (lhs, .matches(rhs)):
                XCTAssertEqual(lhs, rhs(), file: file, line: line)
            case let (lhs, .contains(rhs)):
                let evaluatedRHS = rhs()
                XCTAssert(lhs.contains(evaluatedRHS),
                          "\"\(lhs)\" doesn't contain substring \"\(evaluatedRHS)\"",
                          file: file,
                          line: line)
            }
        }
        return true
    }
}

func reduceLikeOperatorMirror(file: StaticString = #file,
                              line: UInt = #line) -> (Mirror) -> Bool {
    return expectedChildren(
        ("downstream", .contains("TrackingSubscriberBase")),
        ("result", .anything),
        ("initial", .anything),
        ("status", .contains("awaitingSubscription")),
        file: file,
        line: line
    )
}

@available(macOS 10.15, iOS 13.0, *)
internal func testReflection<Output, Failure: Error, Operator: Publisher>(
    file: StaticString = #file,
    line: UInt = #line,
    parentInput: Output.Type,
    parentFailure: Failure.Type,
    description expectedDescription: String?,
    customMirror customMirrorPredicate: ((Mirror) -> Bool)?,
    playgroundDescription: String?,
    _ makeOperator: (CustomConnectablePublisherBase<Output, Failure>) -> Operator
) throws {
    let publisher = CustomConnectablePublisherBase<Output, Failure>(subscription: nil)
    let operatorPublisher = makeOperator(publisher)
    let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
    operatorPublisher.subscribe(tracking)

    let erasedSubscriber =
        try XCTUnwrap(publisher.erasedSubscriber, file: file, line: line)

    XCTAssertEqual((erasedSubscriber as? CustomStringConvertible)?.description,
                   expectedDescription,
                   file: file,
                   line: line)

    if let customMirrorPredicate = customMirrorPredicate {
        let customMirror =
            try XCTUnwrap((erasedSubscriber as? CustomReflectable)?.customMirror,
                          file: file,
                          line: line)
        XCTAssert(customMirrorPredicate(customMirror),
                  "customMirror doesn't satisfy the predicate",
                  file: file,
                  line: line)
    } else {
        XCTAssertFalse(erasedSubscriber is CustomReflectable,
                       "subscriber shouldn't conform to CustomReflectable")
    }

    XCTAssertFalse(erasedSubscriber is CustomDebugStringConvertible,
                   "subscriber shouldn't conform to CustomDebugStringConvertible",
                   file: file,
                   line: line)

    XCTAssertEqual(
        ((erasedSubscriber as? CustomPlaygroundDisplayConvertible)?
            .playgroundDescription as? String),
        playgroundDescription,
        file: file,
        line: line
    )
}

@available(macOS 10.15, iOS 13.0, *)
internal func testSubscriptionReflection<Sut: Publisher>(
    file: StaticString = #file,
    line: UInt = #line,
    description expectedDescription: String,
    customMirror customMirrorPredicate: ((Mirror) -> Bool)?,
    playgroundDescription: String,
    sut: Sut
) throws {
    let tracking = TrackingSubscriberBase<Sut.Output, Sut.Failure>()
    sut.subscribe(tracking)

    let subscription = try XCTUnwrap(tracking.subscriptions.first?.underlying)

    XCTAssertEqual((subscription as? CustomStringConvertible)?.description,
                   expectedDescription,
                   file: file,
                   line: line)

    if let customMirrorPredicate = customMirrorPredicate {
        let customMirror =
        try XCTUnwrap((subscription as? CustomReflectable)?.customMirror,
                      "Subscription doesn't conform to CustomReflectable",
                      file: file,
                      line: line)
        XCTAssert(customMirrorPredicate(customMirror),
                  file: file,
                  line: line)
    } else {
        XCTAssertFalse(subscription is CustomReflectable,
                       "Subscription shouldn't conform to CustomReflectable",
                       file: file,
                       line: line)
    }

    XCTAssertFalse(subscription is CustomDebugStringConvertible,
                   "subscriber shouldn't conform to CustomDebugStringConvertible",
                   file: file,
                   line: line)

    XCTAssertEqual(
        ((subscription as? CustomPlaygroundDisplayConvertible)?
            .playgroundDescription as? String),
        playgroundDescription,
        file: file,
        line: line
    )
}
