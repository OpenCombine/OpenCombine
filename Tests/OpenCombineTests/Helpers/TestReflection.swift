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
internal func testReflection<Operator: Publisher>(
    description expectedDescription: String,
    customMirror customMirrorPredicate: (Mirror) -> Bool,
    playgroundDescription: String,
    _ makeOperator: (CustomPublisherBase<Int, Never>) -> Operator
) throws where Operator.Output: Equatable {
    let publisher = CustomPublisherBase<Int, Never>(subscription: nil)
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
