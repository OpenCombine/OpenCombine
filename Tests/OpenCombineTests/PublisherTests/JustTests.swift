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

@available(macOS 10.15, iOS 13.0, *)
final class JustTests: XCTestCase {

    static let allTests = [
        ("testJustNoInitialDemand", testJustNoInitialDemand),
        ("testCustomMirror", testCustomMirror),
        ("testJustWithInitialDemand", testJustWithInitialDemand),
        ("testLifecycle", testLifecycle),
        ("testCancelOnSubscription", testCancelOnSubscription),
        ("testMinOperatorSpecialization", testMinOperatorSpecialization),
        ("testMaxOperatorSpecialization", testMaxOperatorSpecialization),
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
        ("testDropFirstOperatorSpecialization", testDropFirstOperatorSpecialization),
        ("testDropWhileOperatorSpecialization", testDropWhileOperatorSpecialization),
        ("testFirstOperatorSpecialization", testFirstOperatorSpecialization),
        ("testFirstWhereOperatorSpecializtion", testFirstWhereOperatorSpecializtion),
        ("testLastOperatorSpecialization", testLastOperatorSpecialization),
        ("testLastWhereOperatorSpecializtion", testLastWhereOperatorSpecializtion),
        ("testIgnoreOutputOperatorSpecialization",
         testIgnoreOutputOperatorSpecialization),
        ("testMapOperatorSpecialization", testMapOperatorSpecialization),
        ("testTryMapOperatorSpecialization", testTryMapOperatorSpecialization),
        ("testCompactMapOperatorSpecialization", testCompactMapOperatorSpecialization),
        ("testFilterOperatorSpecialization", testFilterOperatorSpecialization),
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
        ("testOutputAtIndexOperatorSpecialization",
         testOutputAtIndexOperatorSpecialization),
        ("testOutputInRangeOperatorSpecialization",
         testOutputInRangeOperatorSpecialization),
        ("testPrefixOperatorSpecialization", testPrefixOperatorSpecialization),
        ("testPrefixWhileOperatorSpecialization", testPrefixWhileOperatorSpecialization),
        ("testSetFailureTypeOperatorSpecialization",
         testSetFailureTypeOperatorSpecialization),
    ]

    private typealias Sut = Just

    func testJustNoInitialDemand() {
        let just = Sut(42)
        let tracking = TrackingSubscriberBase<Int, Never>()
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Just")])

        tracking.subscriptions.first?.request(.max(100))
        tracking.subscriptions.first?.request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription("Just"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testCustomMirror() throws {
        let just = Sut(42)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        just.subscribe(tracking)

        var reflected = ""
        try dump(XCTUnwrap(downstreamSubscription), to: &reflected)

        XCTAssertEqual(reflected, """
        ▿ Just #0
          - 42

        """)
    }

    func testJustWithInitialDemand() {
        let just = Sut(42)
        let tracking =
            TrackingSubscriberBase<Int, Never>(receiveSubscription: {
                $0.request(.unlimited)
            })
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Just"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testCancelOnSubscription() {
        let just = Sut(42)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Just"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testLifecycle() {
        var deinitCount = 0
        do {
            let just = Sut(42)
            let tracking = TrackingSubscriberBase<Int, Never>(onDeinit: {
                deinitCount += 1
            })
            just.subscribe(tracking)
            tracking.subscriptions.first?.cancel()
        }
        XCTAssertEqual(deinitCount, 1)
    }

    // MARK: - Operator specializations for Just

    func testMinOperatorSpecialization() {
        XCTAssertEqual(Sut(112).min(), Sut(112))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut(1).min(by: comparator), Sut(1))

        XCTAssertEqual(count, 0, "comparator should not be called for min(by:)")
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(Sut(341).max(), Sut(341))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut(2).max(by: comparator), Sut(2))

        XCTAssertEqual(count, 0, "comparator should not be called for max(by:)")
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

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 == $1 }
        XCTAssertEqual(Sut(44).removeDuplicates(by: comparator), Sut(44))

        XCTAssertEqual(count,
                       0,
                       "comparator should not be called for removeDuplicates(by:)")
    }

    func testTryRemoveDuplicatesOperatorSpecialization() {
        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        let throwingComparator: (Int, Int) throws -> Bool = { _, _ in
            count += 1
            throw TestingError.oops
        }
        XCTAssertEqual(try Sut(44).tryRemoveDuplicates(by: comparator).result.get(), 44)
        assertThrowsError(
            try Sut(44).tryRemoveDuplicates(by: throwingComparator).result.get(),
            .oops
        )

        XCTAssertEqual(count, 2)
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

    func testDropFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).dropFirst(), .init(nil))
        XCTAssertEqual(Sut<Int>(10000).dropFirst(100), .init(nil))
        XCTAssertEqual(Sut<Int>(10000).dropFirst(0), .init(10000))
    }

    func testDropWhileOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).drop { $0 != 42 }, .init(42))
        XCTAssertEqual(Sut<Int>(-13).drop { $0 != 42 }, .init(nil))
        XCTAssertEqual(Sut<Int>(1).drop { $0 < 0 }, .init(1))
        XCTAssertEqual(Sut<Int>(1).drop { $0 > 0 }, .init(nil))
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(Sut("f").first(), Sut("f"))
    }

    func testFirstWhereOperatorSpecializtion() {
        XCTAssertEqual(Sut<Int>(42).first { $0 != 42 }, .init(nil))
        XCTAssertEqual(Sut<Int>(-13).first { $0 != 42 }, .init(-13))
        XCTAssertEqual(Sut<Int>(1).first { $0 < 0 }, .init(nil))
        XCTAssertEqual(Sut<Int>(1).first { $0 > 0 }, .init(1))
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(Sut("g").last(), Sut("g"))
    }

    func testLastWhereOperatorSpecializtion() {
        XCTAssertEqual(Sut<Int>(42).last { $0 != 42 }, .init(nil))
        XCTAssertEqual(Sut<Int>(-13).last { $0 != 42 }, .init(-13))
        XCTAssertEqual(Sut<Int>(1).last { $0 < 0 }, .init(nil))
        XCTAssertEqual(Sut<Int>(1).last { $0 > 0 }, .init(1))
    }

    func testIgnoreOutputOperatorSpecialization() {
        XCTAssertTrue(Sut(13.0).ignoreOutput().completeImmediately)
    }

    func testMapOperatorSpecialization() {
        XCTAssertEqual(Sut(42).map(String.init), Sut("42"))
    }

    func testTryMapOperatorSpecialization() {
        XCTAssertEqual(try Sut(42).tryMap(String.init).result.get(), "42")
        assertThrowsError(try Sut(42).tryMap(throwing).result.get()as Int, .oops)
    }

    func testCompactMapOperatorSpecialization() {
        let transform: (Int) -> String? = { $0 == 42 ? String($0) : nil }

        XCTAssertEqual(Sut<Int>(42).compactMap(transform), .init("42"))
        XCTAssertEqual(Sut<Int>(100).compactMap(transform), .init(nil))
    }

    func testFilterOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).filter { $0 != 42 }, .init(nil))
        XCTAssertEqual(Sut<Int>(-13).filter { $0 != 42 }, .init(-13))
        XCTAssertEqual(Sut<Int>(1).filter { $0 < 0 }, .init(nil))
        XCTAssertEqual(Sut<Int>(1).filter { $0 > 0 }, .init(1))
    }

    func testMapErrorOperatorSpecialization() {
        XCTAssertEqual(try Sut(42).mapError { _ in TestingError.oops }.result.get(), 42)
    }

    func testReplaceErrorOperatorSpecialization() {
        XCTAssertEqual(Sut(1).replaceError(with: 100), Sut(1))
    }

    func testReplaceEmptyOperatorSpecialization() {
        XCTAssertEqual(Sut(1).replaceEmpty(with: 100), Sut(1))
    }

    func testRetryOperatorSpecialization() {
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

    func testOutputAtIndexOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(12).output(at: 0), .init(12))
        XCTAssertEqual(Sut<Int>(12).output(at: 1), .init(nil))
        XCTAssertEqual(Sut<Int>(12).output(at: 42), .init(nil))
    }

    func testOutputInRangeOperatorSpecialization() {
        // TODO: Broken in Apple's Combine? (FB6169621)
        // Empty range should result in a nil
        // If this is fixed, this test will fail in compatibility mode so we will need
        // to change our implementation to the correct one.
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< 10), .init(12))
        XCTAssertEqual(Sut<Int>(12).output(in: -10 ..< 10), .init(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: (-10)...), .init(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: -10 ... 10), .init(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: -10 ..< -5), .init(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< 0), .init(12))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ... 0), .init(12))
        XCTAssertEqual(Sut<Int>(12).output(in: 1 ..< 10), .init(nil))
    }

    func testPrefixOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(98).prefix(0), .init(nil))
        XCTAssertEqual(Sut<Int>(98).prefix(1), .init(98))
        XCTAssertEqual(Sut<Int>(98).prefix(1000), .init(98))
    }

    func testPrefixWhileOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).prefix { $0 != 42 }, .init(nil))
        XCTAssertEqual(Sut<Int>(-13).prefix { $0 != 42 }, .init(-13))
        XCTAssertEqual(Sut<Int>(1).prefix { $0 < 0 }, .init(nil))
        XCTAssertEqual(Sut<Int>(1).prefix { $0 > 0 }, .init(1))
    }

    func testSetFailureTypeOperatorSpecialization() {
        XCTAssertEqual(try Sut(73).setFailureType(to: TestingError.self).result.get(), 73)
    }
}
