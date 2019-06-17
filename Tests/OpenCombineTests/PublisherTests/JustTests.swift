//
//  JustTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class JustTests: XCTestCase {

    static let allTests = [
        ("testJustNoInitialDemand", testJustNoInitialDemand),
        ("testJustWithInitialDemand", testJustWithInitialDemand),
        ("testLifecycle", testLifecycle),
        ("testCancelOnSubscription", testCancelOnSubscription),
        ("testMinOperatorSpecialization", testMinOperatorSpecialization),
        ("testTryMinOperatorSpecialization", testTryMinOperatorSpecialization),
        ("testMaxOperatorSpecialization", testMaxOperatorSpecialization),
        ("testTryMaxOperatorSpecialization", testTryMaxOperatorSpecialization),
        ("testContainsOperatorSpecialization", testContainsOperatorSpecialization),
        ("testTryContainsOperatorSpecialization", testTryContainsOperatorSpecialization),
        ("testRemoveDuplicatesOperatorSpecialization",
         testRemoveDuplicatesOperatorSpecialization),
        ("testTryRemoveDuplicatesOperatorSpecialization",
         testTryRemoveDuplicatesOperatorSpecialization),
        ("testAllSatisfyOperatorSpecialization", testAllSatisfyOperatorSpecialization),
        ("testTryAllSatisfyOperatorSpecialization",
         testTryAllSatisfyOperatorSpecialization),
        ("testCollectOperatorSpecialization", testCollectOperatorSpecialization),
        ("testCountOperatorSpecialization", testCountOperatorSpecialization),
        ("testFirstOperatorSpecialization", testFirstOperatorSpecialization),
        ("testLastOperatorSpecialization", testLastOperatorSpecialization),
        ("testIgnoreOutputOperatorSpecialization",
         testIgnoreOutputOperatorSpecialization),
        ("testMapOperatorSpecialization", testMapOperatorSpecialization),
        ("testTryMapOperatorSpecialization", testTryMapOperatorSpecialization),
        ("testMapErrorOperatorSpecialization", testMapErrorOperatorSpecialization),
        ("testReplaceErrorOperatorSpecialization",
         testReplaceErrorOperatorSpecialization),
        ("testReplaceEmptyOperatorSpecialization",
         testReplaceEmptyOperatorSpecialization),
        ("testRetryOperatorSpecialization", testRetryOperatorSpecialization),
        ("testReduceOperatorSpecialization", testReduceOperatorSpecialization),
        ("testTryReduceOperatorSpecialization", testTryReduceOperatorSpecialization),
        ("testScanOperatorSpecialization", testScanOperatorSpecialization),
        ("testTryScanOperatorSpecialization", testTryScanOperatorSpecialization),
        ("testSetFailureTypeOperatorSpecialization",
         testSetFailureTypeOperatorSpecialization),
    ]

    private typealias Sut = Publishers.Just

    func testJustNoInitialDemand() {
        let just = Sut(42)
        let tracking = TrackingSubscriberBase<Never>()
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty)])

        tracking.subscriptions.first?.request(.max(100))
        tracking.subscriptions.first?.request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testJustWithInitialDemand() {
        let just = Sut(42)
        let tracking =
            TrackingSubscriberBase<Never>(receiveSubscription: { $0.request(.unlimited) })
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testCancelOnSubscription() {
        let just = Sut(42)
        let tracking = TrackingSubscriberBase<Never>(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testLifecycle() {
        var deinitCount = 0
        do {
            let just = Sut(42)
            let tracking = TrackingSubscriberBase<Never>(onDeinit: { deinitCount += 1 })
            just.subscribe(tracking)
            tracking.subscriptions.first?.cancel()
        }
        XCTAssertEqual(deinitCount, 1)
    }

    // MARK: - Operator specializations for Just

    func testMinOperatorSpecialization() {
        XCTAssertEqual(Sut(112).min(), Sut(112))
        XCTAssertEqual(Sut(1).min(by: >), Sut(1))
    }

    func testTryMinOperatorSpecialization() {
        XCTAssertEqual(Sut(1).tryMin(by: >), Sut(1))
        XCTAssertEqual(Sut(1).tryMin(by: throwing), Sut(1))
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(Sut(341).max(), Sut(341))
        XCTAssertEqual(Sut(2).max(by: >), Sut(2))
    }

    func testTryMaxOperatorSpecialization() {
        XCTAssertEqual(Sut(2).tryMax(by: >), Sut(2))
        XCTAssertEqual(Sut(2).tryMax(by: throwing), Sut(2))
    }

    func testContainsOperatorSpecialization() {
        XCTAssertEqual(Sut(10).contains(12), Sut(false))
        XCTAssertEqual(Sut(10).contains(10), Sut(true))

        XCTAssertEqual(Sut(64).contains { $0 < 100 }, Sut(true))
        XCTAssertEqual(Sut(14).contains { $0 > 100 }, Sut(false))
    }

    func testTryContainsOperatorSpecialization() {
        XCTAssertFalse(try Sut(0).tryContains { $0 > 0 }.result.get())
        XCTAssertTrue(try Sut(1).tryContains { $0 > 0 }.result.get())
        assertThrowsError(try Sut(1).tryContains(where: throwing).result.get(), .oops)
    }

    func testRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(Sut(1000).removeDuplicates(), Sut(1000))
        XCTAssertEqual(Sut(44).removeDuplicates(by: <), Sut(44))
    }

    func testTryRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(try Sut(44).tryRemoveDuplicates(by: <).result.get(), 44)
        XCTAssertEqual(try Sut(44).tryRemoveDuplicates(by: throwing).result.get(), 44)
    }

    func testAllSatisfyOperatorSpecialization() {
        XCTAssertEqual(Sut(0).allSatisfy { $0 > 0 }, Sut(false))
        XCTAssertEqual(Sut(1).allSatisfy { $0 > 0 }, Sut(true))
    }

    func testTryAllSatisfyOperatorSpecialization() {
        XCTAssertFalse(try Sut(0).tryAllSatisfy { $0 > 0 }.result.get())
        XCTAssertTrue(try Sut(1).tryAllSatisfy { $0 > 0 }.result.get())
        assertThrowsError(try Sut(1).tryAllSatisfy(throwing).result.get(), .oops)
    }

    func testCollectOperatorSpecialization() {
        XCTAssertEqual(Sut(13).collect(), Sut([13]))
    }

    func testCountOperatorSpecialization() {
        XCTAssertEqual(Sut(10000).count(), Sut(1))
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(Sut("f").first(), Sut("f"))
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(Sut("g").last(), Sut("g"))
    }

    func testIgnoreOutputOperatorSpecialization() {
        XCTAssertTrue(Sut(13.0).ignoreOutput().completeImmediately)
    }

    func testMapOperatorSpecialization() {
        XCTAssertEqual(Sut(42).map(String.init), Sut("42"))
    }

    func testTryMapOperatorSpecialization() {
        XCTAssertEqual(try Sut(42).tryMap(String.init).result.get(), "42")
        XCTAssertEqual(try Sut(42).tryMap(String.init).result.get(), "42")
        assertThrowsError(try Sut(42).tryMap(throwing).result.get()as Int, .oops)
    }

    func testMapErrorOperatorSpecialization() {
        XCTAssertEqual(try Sut(42).mapError { _ in TestingError.oops }.result.get(),
                       42)
    }

    func testReplaceErrorOperatorSpecialization() {
        XCTAssertEqual(Sut(1).replaceError(with: 100), Sut(1))
    }

    func testReplaceEmptyOperatorSpecialization() {
        XCTAssertEqual(Sut(1).replaceEmpty(with: 100), Sut(1))
    }

    func testRetryOperatorSpecialization() {
        XCTAssertEqual(Sut(1).retry(), Sut(1))
        XCTAssertEqual(Sut(1).retry(Int.max), Sut(1))
    }

    func testReduceOperatorSpecialization() {
        XCTAssertEqual(Sut(4).reduce(2, +).result, .success(6))
    }

    func testTryReduceOperatorSpecialization() {
        XCTAssertEqual(try Sut(4).tryReduce(2, *).result.get(), 8)
        assertThrowsError(try Sut(4).tryReduce(2, throwing).result.get(), .oops)
    }

    func testScanOperatorSpecialization() {
        XCTAssertEqual(Sut(4).scan(2, +).result, .success(6))
    }

    func testTryScanOperatorSpecialization() {
        XCTAssertEqual(try Sut(4).tryScan(2, *).result.get(), 8)
        assertThrowsError(try Sut(4).tryScan(2, throwing).result.get(), .oops)
    }

    func testSetFailureTypeOperatorSpecialization() {
        XCTAssertEqual(try Sut(73).setFailureType(to: TestingError.self).result.get(), 73)
    }
}
