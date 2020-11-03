//
//  OptionalPublisherTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 18.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 11.0, iOS 14.0, *)
final class OptionalPublisherTests: XCTestCase {

    private typealias Sut<Output> = OptionalPublisher<Output>

    func testSuccessNoInitialDemand() {
        let optional = makePublisher(42)
        let tracking = TrackingSubscriberBase<Int, Never>()
        optional.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Optional")])

        tracking.subscriptions.first?.request(.max(100))
        tracking.subscriptions.first?.request(.max(1))

        XCTAssertEqual(tracking.history, [.subscription("Optional"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testSuccessWithInitialDemand() {
        let optional = makePublisher(42)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        optional.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Optional"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testSuccessCancelOnSubscription() {
        let success = makePublisher(42)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)); $0.cancel() }
        )
        success.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Optional"),
                                          .value(42),
                                          .completion(.finished)])
    }

    func testNil() {
        let success = Sut<Int>(nil)
        let tracking = TrackingSubscriberBase<Int, Never>()
        success.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Empty"),
                                          .completion(.finished)])
    }

    func testRecursion() {
        let optional = makePublisher(42)
        var subscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: {
                subscription = $0
                $0.request(.unlimited)
            },
            receiveValue: { _ in
                subscription?.request(.unlimited)
                return .none
            }
        )
        optional.subscribe(tracking)
    }

    func testReflection() throws {
        try testSubscriptionReflection(description: "Optional",
                                       customMirror: expectedChildren((nil, "42")),
                                       playgroundDescription: "Optional",
                                       sut: Sut(42))
    }

    func testCrashesOnZeroDemand() {
        assertCrashes {
            let tracking =
                TrackingSubscriberBase<Int, Never>(receiveSubscription: {
                    $0.request(.none)
                })
            Sut(42).subscribe(tracking)
        }
    }

    func testLifecycle() {
        var deinitCount = 0
        do {
            let once = makePublisher(42)
            let tracking = TrackingSubscriberBase<Int, Never>(
                onDeinit: { deinitCount += 1 }
            )
            once.subscribe(tracking)
            tracking.subscriptions.first?.cancel()
        }
        XCTAssertEqual(deinitCount, 1)
    }

    // MARK: - Operator specializations for Optional

    func testMinOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(112).min(), Sut(112))
        XCTAssertEqual(Sut<Int>(nil).min(), Sut(nil))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }
        XCTAssertEqual(Sut<Int>(1).min(by: comparator), Sut(1))
        XCTAssertEqual(Sut<Int>(nil).min(by: comparator), Sut(nil))

        XCTAssertEqual(count, 0, "comparator should not be called for min(by:)")
    }

    func testMaxOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(341).max(), Sut(341))
        XCTAssertEqual(Sut<Int>(nil).max(), Sut(nil))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 > $1 }

        XCTAssertEqual(Sut<Int>(2).max(by: comparator), Sut(2))
        XCTAssertEqual(Sut<Int>(nil).max(by: comparator), Sut(nil))

        XCTAssertEqual(count, 0, "comparator should not be called for max(by:)")
    }

    func testContainsOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10).contains(12), Sut(false))
        XCTAssertEqual(Sut<Int>(10).contains(10), Sut(true))
        XCTAssertEqual(Sut<Int>(nil).contains(10), Sut(nil))

        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 < 100 }

        XCTAssertEqual(Sut<Int>(64).contains(where: predicate), Sut(true))
        XCTAssertEqual(Sut<Int>(112).contains(where: predicate), Sut(false))
        XCTAssertEqual(Sut<Int>(nil).contains(where: predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testRemoveDuplicatesOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1000).removeDuplicates(), Sut(1000))
        XCTAssertEqual(Sut<Int>(nil).removeDuplicates(), Sut(nil))

        var count = 0
        let comparator: (Int, Int) -> Bool = { count += 1; return $0 == $1 }

        XCTAssertEqual(Sut<Int>(44).removeDuplicates(by: comparator), Sut(44))
        XCTAssertEqual(Sut<Int>(nil).removeDuplicates(by: comparator), Sut(nil))

        XCTAssertEqual(count,
                       0,
                       "comparator should not be called for removeDuplicates(by:)")
    }

    func testAllSatisfyOperatorSpecialization() {

        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 > 0 }

        XCTAssertEqual(Sut<Int>(0).allSatisfy(predicate), Sut(false))
        XCTAssertEqual(Sut<Int>(1).allSatisfy(predicate), Sut(true))
        XCTAssertEqual(Sut<Int>(nil).allSatisfy(predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testCollectOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(13).collect(), Sut([13]))
        XCTAssertEqual(Sut<Int>(nil).collect(), Sut([]))
    }

    func testCountOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).count(), Sut(1))
        XCTAssertEqual(Sut<Int>(nil).count(), Sut(nil))
    }

    func testDropFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(10000).dropFirst(), Sut(nil))
        XCTAssertEqual(Sut<Int>(10000).dropFirst(100), Sut(nil))
        XCTAssertEqual(Sut<Int>(10000).dropFirst(0), Sut(10000))
        XCTAssertEqual(Sut<Int>(nil).dropFirst(), Sut(nil))
    }

    func testDropWhileOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 != 42 }

        XCTAssertEqual(Sut<Int>(42).drop(while: predicate), Sut(42))
        XCTAssertEqual(Sut<Int>(-13).drop(while: predicate), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).drop(while: predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testFirstOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(3).first(), Sut(3))
        XCTAssertEqual(Sut<Int>(nil).first(), Sut(nil))
    }

    func testFirstWhereOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }

        XCTAssertEqual(Sut<Int>(42).first(where: predicate), Sut(42))
        XCTAssertEqual(Sut<Int>(-13).first(where: predicate), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).first(where: predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testLastOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(4).last(), Sut(4))
        XCTAssertEqual(Sut<Int>(nil).last(), Sut(nil))
    }

    func testLastWhereOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }

        XCTAssertEqual(Sut<Int>(42).last(where: predicate), Sut(42))
        XCTAssertEqual(Sut<Int>(-13).last(where: predicate), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).last(where: predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testFilterOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0 == 42 }

        XCTAssertEqual(Sut<Int>(42).filter(predicate), Sut(42))
        XCTAssertEqual(Sut<Int>(-13).filter(predicate), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).filter(predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testIgnoreOutputOperatorSpecialization() {
        XCTAssertTrue(Sut<Double>(13.0).ignoreOutput().completeImmediately)
    }

    func testMapOperatorSpecialization() {
        var count = 0
        let transform: (Int) -> String = { count += 1; return String($0) }

        XCTAssertEqual(Sut<Int>(42).map(transform), Sut("42"))
        XCTAssertEqual(Sut<Int>(nil).map(transform), Sut(nil))

        XCTAssertEqual(count, 1)
    }

    func testCompactMapOperatorSpecialization() {
        var count = 0
        let transform: (Int) -> String? = {
            count += 1
            return $0 == 42 ? String($0) : nil
        }

        XCTAssertEqual(Sut<Int>(42).compactMap(transform), Sut("42"))
        XCTAssertEqual(Sut<Int>(100).compactMap(transform), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).compactMap(transform), Sut(nil))

        XCTAssertEqual(count, 2)
    }

    func testReplaceErrorOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).replaceError(with: 100), Sut(1))
        XCTAssertEqual(Sut<Int>(nil).replaceError(with: 100), Sut(nil))
    }

    func testReplaceEmptyOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).replaceEmpty(with: 100), Just(1))
        XCTAssertEqual(Sut<Int>(nil).replaceEmpty(with: 100), Just(100))
    }

    func testRetryOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(1).retry(100), Sut(1))
        XCTAssertEqual(Sut<Int>(nil).retry(100), Sut(nil))
    }

    func testReduceOperatorSpecialization() {
        var count = 0
        let plus: (Int, Int) -> Int = { count += 1; return $0 + $1 }

        XCTAssertEqual(Sut<Int>(4).reduce(2, plus), Sut(6))
        XCTAssertEqual(Sut<Int>(nil).reduce(2, plus), Sut(nil))

        XCTAssertEqual(count, 1)
    }

    func testScanOperatorSpecialization() {
        var count = 0
        let plus: (Int, Int) -> Int = { count += 1; return $0 + $1 }

        XCTAssertEqual(Sut<Int>(4).scan(2, plus), Sut(6))
        XCTAssertEqual(Sut<Int>(nil).scan(2, plus), Sut(nil))

        XCTAssertEqual(count, 1)
    }

    func testOutputAtIndexOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(12).output(at: 0), Sut(12))
        XCTAssertEqual(Sut<Int>(nil).output(at: 0), Sut(nil))
        XCTAssertEqual(Sut<Int>(12).output(at: 1), Sut(nil))
        XCTAssertEqual(Sut<Int>(12).output(at: 42), Sut(nil))
    }

    func testOutputAtIndexOperatorSpecializationCrashesOnNegativeIndex() {
        assertCrashes {
            _ = Sut<Int>(12).output(at: -1)
        }
    }

    func testOutputInRangeOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< 10), Sut(12))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< (.max - 2)), Sut(12))
        XCTAssertEqual(Sut<Int>(nil).output(in: 0 ..< 10), Sut(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ..< 0), Sut(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: 0 ... 0), Sut(12))
        XCTAssertEqual(Sut<Int>(12).output(in: 1 ..< 10), Sut(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: ...0), Sut(12))
        XCTAssertEqual(Sut<Int>(12).output(in: ..<0), Sut(nil))
        XCTAssertEqual(Sut<Int>(12).output(in: ..<1), Sut(12))
        XCTAssertEqual(Sut<Int>(12).output(in: Range(uncheckedBounds: (0, -1))), Sut(12))
        XCTAssertEqual(Sut<Int>(12).output(in: Range(uncheckedBounds: (1, -1))), Sut(nil))

        let trackingRange = TrackingRangeExpression(0 ..< 10)
        _ = Sut<Int>(12).output(in: trackingRange)
        XCTAssertEqual(trackingRange.history, [.relativeTo(0 ..< .max)])
    }

    func testOutputInRangeOperatorSpecializationCrashesOnNegativeLowerBound() {
        assertCrashes {
            _ = Sut<Int>(12).output(in: (-1) ... 4)
        }
    }

    func testOutputInRangeOperatorSpecializationCrashesOnTooBigUpperBound() {
        assertCrashes {
            _ = Sut<Int>(12).output(in: 0 ..< (.max - 1))
        }
    }

    func testPrefixOperatorSpecialization() {
        XCTAssertEqual(Sut<Int>(98).prefix(0), Sut(nil))
        XCTAssertEqual(Sut<Int>(98).prefix(1), Sut(98))
        XCTAssertEqual(Sut<Int>(98).prefix(1000), Sut(98))
        XCTAssertEqual(Sut<Int>(nil).prefix(0), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).prefix(1), Sut(nil))
    }

    func testPrefixOperatorSpecializationCrashesOnNegativeLength() {
        assertCrashes {
            _ = Sut<Int>(12).prefix(-1)
        }
    }

    func testPrefixWhileOperatorSpecialization() {
        var count = 0
        let predicate: (Int) -> Bool = { count += 1; return $0.isMultiple(of: 2) }

        XCTAssertEqual(Sut<Int>(98).prefix(while: predicate), Sut(98))
        XCTAssertEqual(Sut<Int>(99).prefix(while: predicate), Sut(nil))
        XCTAssertEqual(Sut<Int>(nil).prefix(while: predicate), Sut(nil))

        XCTAssertEqual(count, 2)
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
@available(macOS 11.0, iOS 14.0, *)
typealias OptionalPublisher<Output> = Optional<Output>.Publisher

@available(macOS 11.0, iOS 14.0, *)
func makePublisher<Output>(_ optional: Output?) -> OptionalPublisher<Output> {
    return optional.publisher
}
#else
typealias OptionalPublisher<Output> = Optional<Output>.OCombine.Publisher

func makePublisher<Output>(_ optional: Output?) -> OptionalPublisher<Output> {
    return optional.ocombine.publisher
}
#endif
