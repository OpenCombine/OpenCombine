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

@available(macOS 10.15, iOS 13.0, *)
internal func testReflection<Output, Failure: Error, Operator: Publisher>(
    parentInput: Output.Type,
    parentFailure: Failure.Type,
    description expectedDescription: String,
    customMirror customMirrorPredicate: (Mirror) -> Bool,
    playgroundDescription: String,
    _ makeOperator: (CustomPublisherBase<Output, Failure>) -> Operator
) throws where Operator.Output: Equatable {
    let publisher = CustomPublisherBase<Output, Failure>(subscription: nil)
    let operatorPublisher = makeOperator(publisher)
    let tracking = TrackingSubscriberBase<Operator.Output, Operator.Failure>()
    operatorPublisher.subscribe(tracking)

    let erasedSubscriber = try XCTUnwrap(publisher.erasedSubscriber)

    XCTAssertEqual((erasedSubscriber as? CustomStringConvertible)?.description,
                   expectedDescription)

    let customMirror =
        try XCTUnwrap((erasedSubscriber as? CustomReflectable)?.customMirror)

    XCTAssert(customMirrorPredicate(customMirror))

    XCTAssertEqual(
        ((erasedSubscriber as? CustomPlaygroundDisplayConvertible)?
            .playgroundDescription as? String),
        playgroundDescription
    )
}

@available(macOS 10.15, iOS 13.0, *)
internal func testSubscriptionReflection<Sut: Publisher>(
    description expectedDescription: String,
    customMirror customMirrorPredicate: (Mirror) -> Bool,
    playgroundDescription: String,
    sut: Sut
) throws where Sut.Output: Equatable {
    let tracking = TrackingSubscriberBase<Sut.Output, Sut.Failure>()
    sut.subscribe(tracking)

    let subscription = try XCTUnwrap(tracking.subscriptions.first?.underlying)

    XCTAssertEqual((subscription as? CustomStringConvertible)?.description,
                   expectedDescription)

    let customMirror =
        try XCTUnwrap((subscription as? CustomReflectable)?.customMirror)

    XCTAssert(customMirrorPredicate(customMirror))

    XCTAssertEqual(
        ((subscription as? CustomPlaygroundDisplayConvertible)?
            .playgroundDescription as? String),
        playgroundDescription
    )
}
