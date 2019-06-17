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

    private typealias Sut<T> = Publishers.Once<T, TestingError>

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

        XCTAssertEqual(Sut<Int>(1).min(by: >).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").min(by: >).result, .failure("error"))
    }

    func testTryMinOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).tryMin(by: >).result, .success(1))
        XCTAssertEqual(Sut<Int>(1).tryMin(by: throwing).result, .success(1))
        XCTAssertEqual(Sut<Int>("error").tryMin(by: throwing).result, .failure("error"))
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(341).max().result, .success(341))
        XCTAssertEqual(Sut<Int>("error").max().result, .failure("error"))

        XCTAssertEqual(Sut<Int>(2).max(by: >).result, .success(2))
        XCTAssertEqual(Sut<Int>("error").max(by: >).result, .failure("error"))
    }

    func testTryMaxOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(2).tryMax(by: >).result, .success(2))
        XCTAssertEqual(Sut<Int>(2).tryMax(by: throwing).result, .success(2))
        XCTAssertEqual(Sut<Int>("error").tryMax(by: throwing).result, .failure("error"))
    }

    func testContainsOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10).contains(12).result, .success(false))
        XCTAssertEqual(Sut<Int>(10).contains(10).result, .success(true))
        XCTAssertEqual(Sut<Int>("error").contains(12).result, .failure("error"))

        XCTAssertEqual(Sut<Int>(64).contains { $0 < 100 }.result, .success(true))
        XCTAssertEqual(Sut<Int>(14).contains { $0 > 100 }.result, .success(false))
        XCTAssertEqual(Sut<Int>("error").contains { $0 > 100 }.result, .failure("error"))
    }

    func testTryContainsOperatorSpecialization() {
        XCTAssertFalse(try Sut<Int>(0).tryContains { $0 > 0 }.result.get())
        XCTAssertTrue(try Sut<Int>(1).tryContains { $0 > 0 }.result.get())
        assertThrowsError(try Sut<Int>(1).tryContains(where: throwing).result.get(),
                          .oops)
        assertThrowsError(try Sut<Int>("error").tryContains(where: throwing).result.get(),
                          "error")
    }

    func testRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1000).removeDuplicates().result, .success(1000))
        XCTAssertEqual(Sut<Int>("error").removeDuplicates().result, .failure("error"))

        XCTAssertEqual(Sut<Int>(44).removeDuplicates(by: <).result, .success(44))
        XCTAssertEqual(Sut<Int>("error").removeDuplicates(by: <).result,
                       .failure("error"))
    }

    func testTryRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(try Sut<Int>(44).tryRemoveDuplicates(by: <).result.get(), 44)
        XCTAssertEqual(try Sut<Int>(44).tryRemoveDuplicates(by: throwing).result.get(),
                       44)
        assertThrowsError(
            try Sut<Int>("error").tryRemoveDuplicates(by: throwing).result.get(),
            "error"
        )
    }

    func testAllSatifyOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(0).allSatisfy { $0 > 0 }.result, .success(false))
        XCTAssertEqual(Sut<Int>(1).allSatisfy { $0 > 0 }.result, .success(true))
        XCTAssertEqual(Sut<Int>("error").allSatisfy { $0 > 0 }.result, .failure("error"))
    }

    func testTryAllSatifyOperatorSpecialization() {
        XCTAssertFalse(try Sut<Int>(0).tryAllSatisfy { $0 > 0 }.result.get())
        XCTAssertTrue(try Sut<Int>(1).tryAllSatisfy { $0 > 0 }.result.get())
        assertThrowsError(try Sut<Int>(1).tryAllSatisfy(throwing).result.get(), .oops)
        assertThrowsError(try Sut<Int>("error").tryAllSatisfy(throwing).result.get(),
                          "error")
    }

    func testCollectOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(13).collect().result, .success([13]))
        XCTAssertEqual(Sut<Int>("error").collect().result, .failure("error"))
    }

    func testCountOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).count().result, .success(1))
        XCTAssertEqual(Sut<Int>("error").count().result, .failure("error"))
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(3).first().result, .success(3))
        XCTAssertEqual(Sut<Int>("error").first().result, .failure("error"))
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).last().result, .success(4))
        XCTAssertEqual(Sut<Int>("error").last().result, .failure("error"))
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
            case .finished:
                break
            default:
                XCTFail()
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

    func testMapErrorOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(42).mapError { _ in "oops" as TestingError }.result,
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

    func testSetFailureTypeOperatorSpecialization() {

        XCTAssertEqual(
            try Publishers.Once<Int, Never>(73)
                .setFailureType(to: TestingError.self)
                .result
                .get(),
            73)
    }
}
