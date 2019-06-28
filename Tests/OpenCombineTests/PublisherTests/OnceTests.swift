//
//  OnceTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class OnceTests: XCTestCase {

    static let allTests = [
        ("testOnceSuccessNoInitialDemand", testOnceSuccessNoInitialDemand),
        ("testOnceSuccessWithInitialDemand", testOnceSuccessWithInitialDemand),
        ("testSuccessCancelOnSubscription", testSuccessCancelOnSubscription),
        ("testOnceFailure", testOnceFailure),
        ("testFailureCancelOnSubscription", testFailureCancelOnSubscription),
        ("testLifecycle", testLifecycle),
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
        ("testAllSatifyOperatorSpecialization", testAllSatifyOperatorSpecialization),
        ("testTryAllSatifyOperatorSpecialization",
         testTryAllSatifyOperatorSpecialization),
        ("testCollectOperatorSpecialization", testCollectOperatorSpecialization),
        ("testCountOperatorSpecialization", testCountOperatorSpecialization),
        ("testDropFirstOperatorSpecialization", testDropFirstOperatorSpecialization),
        ("testDropWhileOperatorSpecialization", testDropWhileOperatorSpecialization),
        ("testTryDropWhileOperatorSpecialization",
         testTryDropWhileOperatorSpecialization),
        ("testFirstOperatorSpecialization", testFirstOperatorSpecialization),
        ("testFirstWhereOperatorSpecializtion", testFirstWhereOperatorSpecializtion),
        ("testTryFirstWhereOperatorSpecializtion",
         testTryFirstWhereOperatorSpecializtion),
        ("testLastOperatorSpecialization", testLastOperatorSpecialization),
        ("testLastWhereOperatorSpecializtion", testLastWhereOperatorSpecializtion),
        ("testTryLastWhereOperatorSpecializtion", testTryLastWhereOperatorSpecializtion),
        ("testFilterOperatorSpecialization", testFilterOperatorSpecialization),
        ("testTryFilterOperatorSpecialization", testTryFilterOperatorSpecialization),
        ("testIgnoreOutputOperatorSpecialization",
         testIgnoreOutputOperatorSpecialization),
        ("testMapOperatorSpecialization", testMapOperatorSpecialization),
        ("testTryMapOperatorSpecialization", testTryMapOperatorSpecialization),
        ("testCompactMapOperatorSpecialization", testCompactMapOperatorSpecialization),
        ("testTryCompactMapOperatorSpecialization",
         testTryCompactMapOperatorSpecialization),
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
        ("testTryPrefixWhileOperatorSpecialization",
         testTryPrefixWhileOperatorSpecialization),
        ("testSetFailureTypeOperatorSpecialization",
         testSetFailureTypeOperatorSpecialization),
    ]

    private typealias Sut<Output> = Publishers.Once<Output, TestingError>

    func testOnceSuccessNoInitialDemand() {
        let success = Sut(42)
        let tracking = TrackingSubscriber()
        success.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty)])

        tracking.subscriptions.first?.request(.max(100))
        tracking.subscriptions.first?.request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testOnceSuccessWithInitialDemand() {
        let just = Sut(42)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.unlimited) })
        just.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testSuccessCancelOnSubscription() {
        let success = Sut(42)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        success.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testOnceFailure() {
        let failure = Sut<Int>("failure" as TestingError)
        let tracking = TrackingSubscriber()
        failure.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .completion(.failure("failure"))])
    }

    func testFailureCancelOnSubscription() {
        let failure = Sut<Int>("failure" as TestingError)
        let tracking = TrackingSubscriber(
            receiveSubscription: { $0.cancel() }
        )
        failure.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription(Subscriptions.empty),
                                          .completion(.failure("failure"))])
    }

    func testLifecycle() {
        var deinitCount = 0
        do {
            let once = Sut(42)
            let tracking = TrackingSubscriber(onDeinit: { deinitCount += 1 })
            once.subscribe(tracking)
            tracking.subscriptions.first?.cancel()
        }
        XCTAssertEqual(deinitCount, 1)
    }

    // MARK: - Operator specializations for Once

    func testMinOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(112).min().result, .success(112))
        XCTAssertEqual(Sut<Int>("error").min().result, .failure("error"))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut<Int>(1).min(by: comparator).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").min(by: comparator).result, .failure("error"))

        XCTAssertEqual(count, 0, "comparator should not be called for min(by:)")
    }

    func testTryMinOperatorSpecialization() {
        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        let throwingComparator: (Int, Int) throws -> Bool = { _, _ in
            count += 1
            throw TestingError.oops
        }
        XCTAssertEqual(Sut<Int>(1).tryMin(by: comparator).result, .success(1))
        XCTAssertEqual(Sut<Int>(1).tryMin(by: throwingComparator).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").tryMin(by: throwingComparator).result,
                       .failure("error"))

        XCTAssertEqual(count, 0, "comparator should not be called for tryMin(by:)")
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(341).max().result, .success(341))
        XCTAssertEqual(Sut<Int>("error").max().result, .failure("error"))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut<Int>(2).max(by: comparator).result, .success(2))
        XCTAssertEqual(Sut<Int>("error").max(by: comparator).result, .failure("error"))

        XCTAssertEqual(count, 0, "comparator should not be called for max(by:)")
    }

    func testTryMaxOperatorSpecialization() {
        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        let throwingComparator: (Int, Int) throws -> Bool = { _, _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(Sut<Int>(2).tryMax(by: comparator).result, .success(2))
        XCTAssertEqual(Sut<Int>(2).tryMax(by: throwingComparator).result, .success(2))
        XCTAssertEqual(Sut<Int>("error").tryMax(by: throwingComparator).result,
                       .failure("error"))

        XCTAssertEqual(count, 0, "comparator should not be called for tryMax(by:)")
    }

    func testContainsOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10).contains(12).result, .success(false))
        XCTAssertEqual(Sut<Int>(10).contains(10).result, .success(true))
        XCTAssertEqual(Sut<Int>("error").contains(12).result, .failure("error"))

        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 < 100 }
        XCTAssertEqual(Sut<Int>(64).contains(where: predicate).result, .success(true))
        XCTAssertEqual(Sut<Int>(112).contains(where: predicate).result, .success(false))
        XCTAssertEqual(Sut<Int>("error").contains(where: predicate).result,
                       .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryContainsOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertFalse(try Sut<Int>(0).tryContains(where: predicate).result.get())
        XCTAssertTrue(try Sut<Int>(1).tryContains(where: predicate).result.get())
        assertThrowsError(
            try Sut<Int>(1).tryContains(where: throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryContains(where: throwingPredicate).result.get(),
            "error"
        )
        XCTAssertEqual(count, 3)
    }

    func testRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1000).removeDuplicates().result, .success(1000))
        XCTAssertEqual(Sut<Int>("error").removeDuplicates().result, .failure("error"))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 == $1 }
        XCTAssertEqual(Sut<Int>(44).removeDuplicates(by: comparator).result, .success(44))
        XCTAssertEqual(Sut<Int>("error").removeDuplicates(by: comparator).result,
                       .failure("error"))

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

        XCTAssertEqual(try Sut<Int>(44).tryRemoveDuplicates(by: comparator).result.get(),
                       44)
        XCTAssertEqual(
            try Sut<Int>(44).tryRemoveDuplicates(by: throwingComparator).result.get(),
            44
        )
        assertThrowsError(
            try Sut<Int>("error")
                .tryRemoveDuplicates(by: throwingComparator).result.get(),
            "error"
        )

        XCTAssertEqual(count,
                       0,
                       "comparator should not be called for tryRemoveDuplicates(by:)")
    }

    func testAllSatifyOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }
        XCTAssertEqual(Sut<Int>(0).allSatisfy(predicate).result, .success(false))
        XCTAssertEqual(Sut<Int>(1).allSatisfy(predicate).result, .success(true))
        XCTAssertEqual(Sut<Int>("error").allSatisfy(predicate).result, .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryAllSatifyOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertFalse(try Sut<Int>(0).tryAllSatisfy(predicate).result.get())
        XCTAssertTrue(try Sut<Int>(1).tryAllSatisfy(predicate).result.get())
        assertThrowsError(
            try Sut<Int>(1).tryAllSatisfy(throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryAllSatisfy(throwingPredicate).result.get(),
            "error"
        )

        XCTAssertEqual(count, 3)
    }

    func testCollectOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(13).collect().result, .success([13]))
        XCTAssertEqual(Sut<Int>("error").collect().result, .failure("error"))
    }

    func testCountOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).count().result, .success(1))
        XCTAssertEqual(Sut<Int>("error").count().result, .failure("error"))
    }

    func testDropFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).dropFirst().result, .success(nil))
        XCTAssertEqual(Sut<Int>(10000).dropFirst(100).result, .success(nil))
        XCTAssertEqual(Sut<Int>(10000).dropFirst(0).result, .success(10000))
        XCTAssertEqual(Sut<Int>("error").dropFirst().result, .success(nil))
    }

    func testDropWhileOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 != 42 }

        XCTAssertEqual(Sut<Int>(42).drop(while: predicate).result, .success(42))
        XCTAssertEqual(Sut<Int>(-13).drop(while: predicate).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").drop(while: predicate).result, .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryDropWhileOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 != 42 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(42).tryDrop(while: predicate).result.get(), 42)
        XCTAssertNil(try Sut<Int>(-13).tryDrop(while: predicate).result.get())
        assertThrowsError(try Sut<Int>("error").tryDrop(while: predicate).result.get(),
                          "error")

        assertThrowsError(
            try Sut<Int>(42).tryDrop(while: throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryDrop(while: throwingPredicate).result.get(),
            "error"
        )

        XCTAssertEqual(count, 3)
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(3).first().result, .success(3))
        XCTAssertEqual(Sut<Int>("error").first().result, .failure("error"))
    }

    func testFirstWhereOperatorSpecializtion() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }

        XCTAssertEqual(Sut<Int>(42).first(where: predicate).result, .success(42))
        XCTAssertEqual(Sut<Int>(-13).first(where: predicate).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").first(where: predicate).result,
                       .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryFirstWhereOperatorSpecializtion() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(42).tryFirst(where: predicate).result.get(), 42)
        XCTAssertNil(try Sut<Int>(-13).tryFirst(where: predicate).result.get())
        assertThrowsError(try Sut<Int>("error").tryFirst(where: predicate).result.get(),
                          "error")

        assertThrowsError(
            try Sut<Int>(42).tryFirst(where: throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryFirst(where: throwingPredicate).result.get(),
            "error"
        )

        XCTAssertEqual(count, 3)
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).last().result, .success(4))
        XCTAssertEqual(Sut<Int>("error").last().result, .failure("error"))
    }

    func testLastWhereOperatorSpecializtion() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }

        XCTAssertEqual(Sut<Int>(42).last(where: predicate).result, .success(42))
        XCTAssertEqual(Sut<Int>(-13).last(where: predicate).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").last(where: predicate).result,
                       .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryLastWhereOperatorSpecializtion() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(42).tryLast(where: predicate).result.get(), 42)
        XCTAssertNil(try Sut<Int>(-13).tryLast(where: predicate).result.get())
        assertThrowsError(try Sut<Int>("error").tryLast(where: predicate).result.get(),
                          "error")

        assertThrowsError(
            try Sut<Int>(42).tryLast(where: throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryLast(where: throwingPredicate).result.get(),
            "error"
        )

        XCTAssertEqual(count, 3)
    }

    func testFilterOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }

        XCTAssertEqual(Sut<Int>(42).filter(predicate).result, .success(42))
        XCTAssertEqual(Sut<Int>(-13).filter(predicate).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").filter(predicate).result,
                       .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryFilterOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(42).tryFilter(predicate).result.get(), 42)
        XCTAssertNil(try Sut<Int>(-13).tryFilter(predicate).result.get())
        assertThrowsError(try Sut<Int>("error").tryFilter(predicate).result.get(),
                          "error")

        assertThrowsError(
            try Sut<Int>(42).tryFilter(throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryFilter(throwingPredicate).result.get(),
            "error"
        )

        XCTAssertEqual(count, 3)
    }

    func testIgnoreOutputOperatorSpecialization() {
        XCTAssertTrue(Sut<Double>(13.0).ignoreOutput().completeImmediately)
        XCTAssertTrue(Sut<Double>("error").ignoreOutput().completeImmediately)

        do {
            var completion: Subscribers.Completion<TestingError>?
            _ = Sut<Double>("error").ignoreOutput()
                .sink(receiveCompletion: { completion = $0 },
                      receiveValue: { _ in })

            switch completion {
            case .finished?:
                break
            default:
                XCTFail("ignoreOutput should send 'finished' completion for Once")
            }
        }
    }

    func testMapOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).map(String.init).result, .success("42"))
        XCTAssertEqual(Sut<Int>("error").map(String.init).result, .failure("error"))
    }

    func testTryMapOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(42).tryMap(String.init).result.get(), "42")
        XCTAssertEqual(try Sut<Int>(42).tryMap(String.init).result.get(), "42")
        assertThrowsError(try Sut<Int>(42).tryMap(throwing).result.get() as Int, "oops")
        assertThrowsError(try Sut<Int>("error").tryMap(throwing).result.get() as Int,
                          "error")
    }

    func testCompactMapOperatorSpecialization() {
        var count = 0
        let transform: (Int) -> String? = {
            count += 1
            return $0 == 42 ? String($0) : nil
        }

        XCTAssertEqual(Sut<Int>(42).compactMap(transform).result, .success("42"))
        XCTAssertEqual(Sut<Int>(100).compactMap(transform).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").map(transform).result, .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryCompactMapOperatorSpecialization() {
        var count = 0
        let transform: (Int) -> String? = {
            count += 1
            return $0 == 42 ? String($0) : nil
        }
        let throwingTrasnform: (Int) throws -> String? = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(42).tryCompactMap(transform).result.get(), "42")
        XCTAssertNil(try Sut<Int>(100).tryCompactMap(transform).result.get())
        assertThrowsError(try Sut<Int>(42).tryMap(throwingTrasnform).result.get(), .oops)
        assertThrowsError(try Sut<Int>("error").tryMap(throwingTrasnform).result.get(),
                          "error")

        XCTAssertEqual(count, 3)
    }

    func testMapErrorOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).mapError { _ in TestingError.oops }.result,
                       .success(42))
        XCTAssertEqual(
            Sut<Int>("error")
                .mapError { TestingError(description: $0.description.uppercased()) }
                .result,
            .failure("ERROR")
        )
    }

    func testReplaceErrorOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).replaceError(with: 100).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").replaceError(with: 100).result, .success(100))
    }

    func testReplaceEmptyOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).replaceEmpty(with: 100).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").replaceEmpty(with: 100).result,
                       .failure("error"))
    }

    func testRetryOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).retry().result, .success(1))
        XCTAssertEqual(Sut<Int>("error").retry().result, .failure("error"))

        XCTAssertEqual(Sut<Int>(1).retry(100).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").retry(100).result, .failure("error"))
    }

    func testReduceOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).reduce(2, +).result, .success(6))
        XCTAssertEqual(Sut<Int>("error").reduce(2, +).result, .failure("error"))
    }

    func testTryReduceOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(4).tryReduce(2, *).result.get(), 8)
        assertThrowsError(try Sut<Int>(4).tryReduce(2, throwing).result.get(), "oops")
        assertThrowsError(try Sut<Int>("error").tryReduce(2, throwing).result.get(),
                          "error")
    }

    func testScanOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).scan(2, +).result, .success(6))
        XCTAssertEqual(Sut<Int>("error").scan(2, +).result, .failure("error"))
    }

    func testTryScanOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(4).tryScan(2, *).result.get(), 8)
        assertThrowsError(try Sut<Int>(4).tryScan(2, throwing).result.get(), "oops")
        assertThrowsError(try Sut<Int>("error").tryScan(2, throwing).result.get(),
                          "error")
    }

    func testOutputAtIndexOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(12).output(at: 0).result, .success(12))
        XCTAssertEqual(Sut<Int>(12).output(at: 1).result, .success(nil))
        XCTAssertEqual(Sut<Int>(12).output(at: 42).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").output(at: 42).result, .failure("error"))
    }

    func testOutputInRangeOperatorSpecialization() {
        // TODO: Broken in Apple's Combine? (FB6169621)
        // Empty range should result in a nil
        // If this is fixed, this test will fail in compatibility mode so we will need
        // to change our implementation to the correct one.
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< 10).result, .success(12))
        XCTAssertEqual(Sut<Int>(12).output(in: -10 ..< 10).result, .success(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: (-10)...).result, .success(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: -10 ... 10).result, .success(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: -10 ..< -5).result, .success(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< 0).result, .success(12))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ... 0).result, .success(12))
        XCTAssertEqual(Sut<Int>(12).output(in: 1 ..< 10).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").output(in: 0 ..< 10).result, .failure("error"))
    }

    func testPrefixOperatorSpecialization() {
        // TODO: Seems broken in Apple's Combine (FB6168300)
        // If this is fixed, this test will fail in compatibility mode so we will need
        // to change our implementation to the correct one.
        XCTAssertEqual(Sut<Int>(98).prefix(0).result, .success(98))
        XCTAssertEqual(Sut<Int>(98).prefix(1).result, .success(nil))
        XCTAssertEqual(Sut<Int>(98).prefix(1000).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").prefix(0).result, .failure("error"))
        XCTAssertEqual(Sut<Int>("error").prefix(1).result, .failure("error"))
    }

    func testPrefixWhileOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0.isMultiple(of: 2) }

        XCTAssertEqual(Sut<Int>(98).prefix(while: predicate).result, .success(98))
        XCTAssertEqual(Sut<Int>(99).prefix(while: predicate).result, .success(nil))
        XCTAssertEqual(Sut<Int>("error").prefix(while: predicate).result,
                       .failure("error"))

        XCTAssertEqual(count, 2)
    }

    func testTryPrefixWhileOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0.isMultiple(of: 2) }
        let throwingPredicate: (Int) throws -> Bool = { _ in
            count += 1
            throw TestingError.oops
        }

        XCTAssertEqual(try Sut<Int>(98).tryPrefix(while: predicate).result.get(), 98)
        XCTAssertNil(try Sut<Int>(99).tryPrefix(while: predicate).result.get())

        assertThrowsError(
            try Sut<Int>(98).tryPrefix(while: throwingPredicate).result.get(),
            .oops
        )
        assertThrowsError(
            try Sut<Int>("error").tryPrefix(while: throwingPredicate).result.get(),
            "error"
        )
    }

    func testSetFailureTypeOperatorSpecialization() {

        XCTAssertEqual(
            try Publishers.Once<Int, Never>(73)
                .setFailureType(to: TestingError.self)
                .result
                .get(),
            73
        )
    }
}
