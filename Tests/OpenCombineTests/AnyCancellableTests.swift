//
//  AnyCancellableTests.swift
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
final class AnyCancellableTests: PerformanceTestCase {

    static let allTests = [
        ("testClosureInitialized", testClosureInitialized),
        ("testCancelableInitialized", testCancelableInitialized),
        ("testCancelTwice", testCancelTwice),
        ("testStoreInArbitraryCollection", testStoreInArbitraryCollection),
        ("testStoreInSet", testStoreInSet),
        ("testDestructionPerformance", testDestructionPerformance),
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

        final class CancellableObject: Cancellable {

            var fired = false

            func cancel() {
                fired = true
            }
        }

        let cancelable = CancellableObject()
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

    func testStoreInArbitraryCollection() {

        var disposeBag = DisposeBag()

        XCTAssertEqual(disposeBag.history, [.emptyInit])

        let cancellable1 = AnyCancellable({})
        cancellable1.store(in: &disposeBag)

        XCTAssertEqual(disposeBag.history, [.emptyInit, .append])

        let cancellable2 = AnyCancellable(cancellable1)
        cancellable2.store(in: &disposeBag)

        XCTAssertEqual(disposeBag.history, [.emptyInit, .append, .append])

        XCTAssertEqual(disposeBag.storage, [cancellable1, cancellable2])
    }

    func testStoreInSet() {

        var disposeBag = Set<AnyCancellable>()

        let cancellable1 = AnyCancellable({})
        cancellable1.store(in: &disposeBag)

        XCTAssertEqual(disposeBag, [cancellable1])

        let cancellable2 = AnyCancellable(cancellable1)
        cancellable2.store(in: &disposeBag)

        XCTAssertEqual(disposeBag, [cancellable1, cancellable2])

        cancellable2.store(in: &disposeBag)
        XCTAssertEqual(disposeBag, [cancellable1, cancellable2])
    }

    func testDestructionPerformance() throws {
        try benchmark(executionCount: 100) {

            // Create a chain of AnyCancellables
            var anyCancellable = AnyCancellable({})

            for _ in 0 ..< 10000 {
                anyCancellable = AnyCancellable(anyCancellable)
            }
        }
    }
}
