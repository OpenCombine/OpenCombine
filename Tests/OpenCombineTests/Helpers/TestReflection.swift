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
func expectedChildren(
    _ expectedChildren: (String?, ExpectedMirrorChildValue)...
) -> (Mirror) -> Bool {
    return { mirror in

        let actualChildren = mirror
            .children
            .map { ($0, String(describing: $1)) }

        XCTAssertEqual(actualChildren.count,
                       expectedChildren.count,
                       "The children collections are of different sizes")

        for (actualChild, expectedChild) in zip(actualChildren, expectedChildren) {
            XCTAssertEqual(actualChild.0, expectedChild.0)
            switch (actualChild.1, expectedChild.1) {
            case (_, .anything):
                continue
            case let (lhs, .matches(rhs)):
                XCTAssertEqual(lhs, rhs())
            case let (lhs, .contains(rhs)):
                let evaluatedRHS = rhs()
                XCTAssert(lhs.contains(evaluatedRHS),
                          "\"\(lhs)\" doesn't contain substring \"\(evaluatedRHS)\"")
            }
        }
        return true
    }
}

func reduceLikeOperatorMirror() -> (Mirror) -> Bool {
    return expectedChildren(
        ("downstream", .contains("TrackingSubscriberBase")),
        ("result", .anything),
        ("initial", .anything),
        ("status", .anything)
    )
}

@available(macOS 10.15, iOS 13.0, *)
internal func testReflection<Output, Failure: Error, Operator: Publisher>(
    parentInput: Output.Type,
    parentFailure: Failure.Type,
    description expectedDescription: String?,
    customMirror customMirrorPredicate: ((Mirror) -> Bool)?,
    playgroundDescription: String?,
    subscriberIsAlsoSubscription: Bool = true,
    _ makeOperator: (CustomConnectablePublisherBase<Output, Failure>) -> Operator
) throws {
    let publisher = CustomConnectablePublisherBase<Output, Failure>(subscription: nil)
    let operatorPublisher = makeOperator(publisher)
    let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
    operatorPublisher.subscribe(tracking)

    let erasedSubscriber =
        try XCTUnwrap(publisher.erasedSubscriber)

    XCTAssertEqual((erasedSubscriber as? CustomStringConvertible)?.description,
                   expectedDescription)

    if let customMirrorPredicate = customMirrorPredicate {
        let customMirror =
            try XCTUnwrap((erasedSubscriber as? CustomReflectable)?.customMirror)
        XCTAssert(customMirrorPredicate(customMirror),
                  "customMirror doesn't satisfy the predicate")
    } else {
        XCTAssertFalse(erasedSubscriber is CustomReflectable,
                       "subscriber shouldn't conform to CustomReflectable")
    }

    XCTAssertFalse(erasedSubscriber is CustomDebugStringConvertible,
                   "subscriber shouldn't conform to CustomDebugStringConvertible")

    XCTAssertEqual(
        ((erasedSubscriber as? CustomPlaygroundDisplayConvertible)?
            .playgroundDescription as? String),
        playgroundDescription
    )

    if subscriberIsAlsoSubscription {
        publisher.send(subscription: CustomSubscription())
        let subscription = try XCTUnwrap(tracking.subscriptions.first?.underlying)

        XCTAssertEqual((subscription as? CustomStringConvertible)?.description,
                       expectedDescription)

        if let customMirrorPredicate = customMirrorPredicate {
            let customMirror =
                try XCTUnwrap((subscription as? CustomReflectable)?.customMirror)
            XCTAssert(customMirrorPredicate(customMirror),
                      "customMirror doesn't satisfy the predicate")
        } else {
            XCTAssertFalse(subscription is CustomReflectable,
                           "subscription shouldn't conform to CustomReflectable")
        }

        XCTAssertFalse(subscription is CustomDebugStringConvertible,
                       "subscription shouldn't conform to CustomDebugStringConvertible")

        XCTAssertEqual(
            ((subscription as? CustomPlaygroundDisplayConvertible)?
                .playgroundDescription as? String),
            playgroundDescription
        )
    }
}

@available(macOS 10.15, iOS 13.0, *)
internal func testSubscriptionReflection<Sut: Publisher>(
    description expectedDescription: String,
    customMirror customMirrorPredicate: ((Mirror) -> Bool)?,
    playgroundDescription: String,
    sut: Sut
) throws {
    let tracking = TrackingSubscriberBase<Sut.Output, Sut.Failure>()
    sut.subscribe(tracking)

    let subscription = try XCTUnwrap(tracking.subscriptions.first?.underlying)

    XCTAssertEqual((subscription as? CustomStringConvertible)?.description,
                   expectedDescription)

    if let customMirrorPredicate = customMirrorPredicate {
        let customMirror =
        try XCTUnwrap((subscription as? CustomReflectable)?.customMirror,
                      "Subscription doesn't conform to CustomReflectable")
        XCTAssert(customMirrorPredicate(customMirror))
    } else {
        XCTAssertFalse(subscription is CustomReflectable,
                       "Subscription shouldn't conform to CustomReflectable")
    }

    XCTAssertFalse(subscription is CustomDebugStringConvertible,
                   "Subscription shouldn't conform to CustomDebugStringConvertible")

    XCTAssertEqual(
        ((subscription as? CustomPlaygroundDisplayConvertible)?
            .playgroundDescription as? String),
        playgroundDescription
    )
}

/// Prior to iOS 14 there was a bug in PassthroughSubject and
/// CurrentValueSubject when after cancelling the subscription we couldn't
/// reflect the subscription.
@available(macOS, deprecated: 10.16, message: """
If macOS 10.16/11.0 has already been released, this property should be removed
""")
@available(iOS, deprecated: 14, message: """
If iOS 14  has already been released, this property should be removed
""")
var hasCustomMirrorUseAfterFreeBug: Bool { // swiftlint:disable:this let_var_whitespace
#if OPENCOMBINE_COMPATIBILITY_TEST
    if #available(macOS 10.16, iOS 14.0, *) {
        return false
    } else {
        return true
    }
#else
    return false
#endif
}
