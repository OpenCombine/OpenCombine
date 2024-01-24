//
//  EmptySubscriptionTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 23.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class EmptySubscriptionTests: XCTestCase {

    func testSingleInstance() {
        XCTAssertEqual(Subscriptions.empty.combineIdentifier,
                       Subscriptions.empty.combineIdentifier)
    }

    func testReflection() throws {
        XCTAssertEqual((Subscriptions.empty as? CustomStringConvertible)?.description,
                       "Empty")

        XCTAssertEqual(
            (Subscriptions.empty as? CustomPlaygroundDisplayConvertible)?
                .playgroundDescription as? String,
            "Empty"
        )

        XCTAssertFalse(Subscriptions.empty is CustomDebugStringConvertible)

        let mirror =
            try XCTUnwrap((Subscriptions.empty as? CustomReflectable)?.customMirror)

        XCTAssertTrue(childrenIsEmpty(mirror))
    }
}
