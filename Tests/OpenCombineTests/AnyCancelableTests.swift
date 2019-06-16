//
//  AnyCancelableTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class AnyCancelableTests: XCTestCase {

    static let allTests = [
        ("testClosureInitialized", testClosureInitialized),
        ("testCancelableInitialized", testCancelableInitialized),
        ("testCancelTwice", testCancelTwice),
    ]

    func testClosureInitialized() {

        var fired = false

        let sut = AnyCancellable { fired = true }

        XCTAssertFalse(fired)

        sut.cancel()

        XCTAssertTrue(fired)

        fired = false

        do {
            _ = AnyCancellable { fired = true }
        }

        XCTAssertTrue(fired, "AnyCancelable should call cancel() on deinit")
    }

    func testCancelableInitialized() {

        final class C: Cancellable {

            var fired = false

            func cancel() {
                fired = true
            }
        }

        let cancelable = C()
        let sut = AnyCancellable(cancelable)

        XCTAssertFalse(cancelable.fired)

        sut.cancel()

        XCTAssertTrue(cancelable.fired)

        cancelable.fired = false

        do {
            _ = AnyCancellable(cancelable)
        }

        XCTAssertTrue(cancelable.fired, "AnyCancelable should call cancel() on deinit")
    }

    func testCancelTwice() {

        var counter = 0

        let cancelable = AnyCancellable { counter += 1 }

        XCTAssertEqual(counter, 0)
        cancelable.cancel()
        XCTAssertEqual(counter, 1)
        cancelable.cancel()
        XCTAssertEqual(counter, 1, "cancel() closure should only be invoked once")
    }
}
