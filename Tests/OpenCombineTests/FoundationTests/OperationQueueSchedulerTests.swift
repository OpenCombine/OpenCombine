//
//  OperationQueueSchedulerTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2020.
//

import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class OperationQueueSchedulerTests: XCTestCase {

    // MARK: - Scheduler.SchedulerTimeType

    func testSchedulerTimeTypeDistance() {
        RunLoopSchedulerTests.testSchedulerTimeTypeDistance(OperationQueueScheduler.self)
    }

    func testSchedulerTimeTypeAdvanced() {
        RunLoopSchedulerTests.testSchedulerTimeTypeAdvanced(OperationQueueScheduler.self)
    }

    func testSchedulerTimeTypeEquatable() {
        RunLoopSchedulerTests.testSchedulerTimeTypeEquatable(OperationQueueScheduler.self)
    }

    func testSchedulerTimeTypeCodable() throws {
        try RunLoopSchedulerTests
            .testSchedulerTimeTypeCodable(OperationQueueScheduler.self)
    }

    // MARK: - Scheduler.SchedulerTimeType.Stride

    func testStrideToTimeInterval() {
        RunLoopSchedulerTests.testStrideToTimeInterval(OperationQueueScheduler.self)
    }

    func testStrideFromTimeInterval() {
        RunLoopSchedulerTests.testStrideFromTimeInterval(OperationQueueScheduler.self)
    }

    func testStrideFromNumericValue() {
        RunLoopSchedulerTests.testStrideFromNumericValue(OperationQueueScheduler.self)
    }

    func testStrideComparable() {
        RunLoopSchedulerTests.testStrideComparable(OperationQueueScheduler.self)
    }

    func testStrideMultiplication() {
        RunLoopSchedulerTests.testStrideMultiplication(OperationQueueScheduler.self)
    }

    func testStrideAddition() {
        RunLoopSchedulerTests.testStrideAddition(OperationQueueScheduler.self)
    }

    func testStrideSubtraction() {
        RunLoopSchedulerTests.testStrideSubtraction(OperationQueueScheduler.self)
    }

    func testStrideCodable() throws {
        try RunLoopSchedulerTests.testStrideCodable(OperationQueueScheduler.self)
    }

    // MARK: - Scheduler

#if canImport(Darwin)
    // FIXME: These tests crash with swift-corelibs-foundation.
    // The issue has been resolved in
    // https://github.com/apple/swift-corelibs-foundation/pull/2779
    // but it hasn't made it into an official release yet.

    func testScheduleActionOnceNowWithTestQueue() {
        let queue = TestOperationQueue()
        let scheduler = makeScheduler(queue)

        let counter = Atomic(0)
        scheduler.schedule {
            counter.do { $0 += 1 }
        }

        XCTAssertEqual(queue.history.count, 1)

        guard case let .addOperation(op as BlockOperation)? = queue.history.first else {
            XCTFail("Unexpected history")
            return
        }

        queue.waitUntilAllOperationsAreFinished()

        XCTAssertEqual(counter.value, 1)
        op.main()
        XCTAssertEqual(counter.value, 2)
        op.main()
        XCTAssertEqual(counter.value, 3)
    }

    func testScheduleActionOnceNowWithRealQueue() {
        let mainQueue = OperationQueue.main
        let now = Date()
        var actualDate = Date.distantPast
        executeOnBackgroundThread {
            makeScheduler(mainQueue).schedule {
                XCTAssertTrue(Thread.isMainThread)
                actualDate = Date()
                XCTAssertNotNil(OperationQueue.current)
                RunLoop.current.run(until: Date() + 0.01)
            }
        }

        XCTAssertEqual(actualDate, .distantPast)
        RunLoop.main.run(until: Date() + 0.05)
        XCTAssertEqual(actualDate.timeIntervalSinceReferenceDate,
                       now.timeIntervalSinceReferenceDate,
                       accuracy: 0.1)
    }

    func testScheduleActionOnceLaterWithTestQueue() {
        let queue = TestOperationQueue()
        let scheduler = makeScheduler(queue)
        let desiredDelay: TimeInterval = 0.6

        let counter = Atomic(0)
        scheduler.schedule(after: scheduler.now.advanced(by: .init(desiredDelay))) {
            counter.do { $0 += 1 }
        }

        XCTAssertEqual(queue.history.count, 1)

        guard case let .addOperation(op)? = queue.history.first else {
            XCTFail("Unexpected history")
            return
        }
        XCTAssertFalse(op is BlockOperation)
        XCTAssertFalse(op.isReady)
        XCTAssertFalse(op.isFinished)
        XCTAssertFalse(op.isCancelled)
        XCTAssertFalse(op.isAsynchronous)
        XCTAssertFalse(op.isConcurrent)
        XCTAssert(op is Cancellable)

        XCTAssertEqual(counter.value, 0)
        let now = Date()
        queue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(counter.value, 1)
        XCTAssertEqual(Date().timeIntervalSinceReferenceDate,
                       (now + desiredDelay).timeIntervalSinceReferenceDate,
                       accuracy: desiredDelay / 3)

        op.main()
        XCTAssertEqual(counter.value, 1)
    }

    func testScheduleActionOnceLaterWithRealQueue() {
        let mainQueue = OperationQueue.main
        let startDate = Date()
        var actualDate = Date.distantPast
        let desiredDelay: TimeInterval = 2
        executeOnBackgroundThread {
            let scheduler = makeScheduler(mainQueue)
            scheduler
                .schedule(after: scheduler.now.advanced(by: .init(desiredDelay))) {
                    XCTAssertTrue(Thread.isMainThread)
                    actualDate = Date()
                    XCTAssertNotNil(OperationQueue.current)
                }
        }

        XCTAssertEqual(actualDate, .distantPast)
        RunLoop.main.run(until: Date() + desiredDelay * 2)
        XCTAssertEqual(
            actualDate.timeIntervalSinceReferenceDate -
                startDate.timeIntervalSinceReferenceDate,
            desiredDelay,
            accuracy: desiredDelay / 3
        )
    }

    func testScheduleRepeatingWithTestQueue() {
        let queue = TestOperationQueue()
        let scheduler = makeScheduler(queue)
        let desiredDelay: TimeInterval = 0.7
        let desiredInterval: TimeInterval = 0.3

        let expectation10ticks = expectation(description: "10 ticks")
        expectation10ticks.expectedFulfillmentCount = 10

        let counter = Atomic(0)
        let cancellable = scheduler
            .schedule(after: scheduler.now.advanced(by: .init(desiredDelay)),
                      interval: .init(desiredInterval)) {
                counter.do { $0 += 1 }
                expectation10ticks.fulfill()
            }

        XCTAssertEqual(queue.history.count, 1)

        guard case let .addOperation(op)? = queue.history.first else {
            XCTFail("Unexpected history")
            return
        }

        XCTAssertFalse(op is BlockOperation)
        XCTAssertFalse(op.isReady)
        XCTAssertFalse(op.isFinished)
        XCTAssertFalse(op.isCancelled)
        XCTAssertFalse(op.isAsynchronous)
        XCTAssertFalse(op.isConcurrent)
        XCTAssert(op is Cancellable)
        XCTAssert(cancellable is AnyCancellable)

        XCTAssertEqual(counter.value, 0)
        wait(for: [expectation10ticks], timeout: 5)
        cancellable.cancel()
        XCTAssertEqual(counter.value, 10)
        XCTAssertEqual(queue.history.count, 11)

        op.main()
        XCTAssertEqual(counter.value, 10)
    }

    func testScheduleRepeatingWithRealQueue() {
        let mainQueue = OperationQueue.main

        let expectation10ticks = expectation(description: "10 ticks")
        expectation10ticks.expectedFulfillmentCount = 10

        let startDate = Date().timeIntervalSinceReferenceDate

        let ticks = Atomic([TimeInterval]())

        let desiredDelay: TimeInterval = 0.7
        let desiredInterval: TimeInterval = 0.3

        let cancellable = executeOnBackgroundThread { () -> Cancellable in
            let scheduler = makeScheduler(mainQueue)
            return scheduler
                .schedule(after: scheduler.now.advanced(by: .init(desiredDelay)),
                          interval: .init(desiredInterval)) {
                    XCTAssertTrue(Thread.isMainThread)
                    ticks.do { $0.append(Date().timeIntervalSinceReferenceDate) }
                    XCTAssertNotNil(OperationQueue.current)
                    expectation10ticks.fulfill()
                    RunLoop.current.run(until: Date() + 0.001)
                }
        }

        XCTAssert(cancellable is AnyCancellable)

        XCTAssertEqual(ticks.value.count, 0)
        RunLoop.main.run(until: Date() + 0.001)
        XCTAssertEqual(ticks.value.count, 0)

        wait(for: [expectation10ticks], timeout: 5)

        if ticks.value.isEmpty {
            XCTFail("The scheduler doesn't work")
            return
        }

        let actualDelay = ticks.value[0] - startDate
        let actualIntervals = zip(ticks.value.dropFirst(), ticks.value.dropLast()).map(-)
        let averageInterval = actualIntervals.reduce(0, +) / Double(actualIntervals.count)

        XCTAssertEqual(actualDelay,
                       desiredDelay,
                       accuracy: desiredDelay / 3,
                       """
                       Actual delay (\(actualDelay)) deviates from desired delay \
                       (\(desiredDelay)) too much
                       """)

        XCTAssertEqual(averageInterval,
                       desiredInterval,
                       accuracy: desiredInterval / 3,
                       """
                       Actual average interval (\(averageInterval)) deviates from \
                       desired interval (\(desiredInterval)) too much.

                       Actual intervals: \(actualIntervals)
                       """)

        cancellable.cancel()
        let numberOfTicksRightAfterCancellation = ticks.value.count
        RunLoop.main.run(until: Date() + 1)
        let numberOfTicksOneSecondAfterCancellation = ticks.value.count
        XCTAssertEqual(numberOfTicksRightAfterCancellation,
                       numberOfTicksOneSecondAfterCancellation)
    }
#endif // canImport(Darwin)

    func testMinimumTolerance() {
        let scheduler = makeScheduler(.main)
        XCTAssertEqual(scheduler.minimumTolerance, .init(0))
    }

    func testNow() {
        let scheduler = makeScheduler(.main)
        XCTAssertEqual(scheduler.now.date.timeIntervalSinceReferenceDate,
                       Date().timeIntervalSinceReferenceDate,
                       accuracy: 0.001)
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)

private typealias OperationQueueScheduler = OperationQueue

private func makeScheduler(_ queue: OperationQueue) -> OperationQueueScheduler {
    return queue
}

#else

private typealias OperationQueueScheduler = OperationQueue.OCombine

private func makeScheduler(_ queue: OperationQueue) -> OperationQueueScheduler {
    return queue.ocombine
}

#endif

@available(macOS 10.15, iOS 13.0, *)
extension OperationQueueScheduler.SchedulerTimeType.Stride
    : TimeIntervalBackedSchedulerStride
{}

@available(macOS 10.15, iOS 13.0, *)
extension OperationQueueScheduler.SchedulerTimeType: DateBackedSchedulerTimeType {}

extension OperationQueueScheduler: RunLoopLikeScheduler {}

private final class TestOperationQueue: OperationQueue {

    enum Event {
        case progress
        case addOperation(Operation)
        case addOperations([Operation], waitUntilFinished: Bool)
        case addBlockOperation(() -> Void)
        case addBarrierBlock(() -> Void)
        case getMaxConcurrentOperationCount
        case setMaxConcurrentOperationCount(Int)
        case getIsSuspended
        case setIsSuspended(Bool)
        case getName
        case setName(String?)
        case getQualityOfService
        case setQualityOfService(QualityOfService)
        case getUnderlyingQueue
        case setUnderlyingQueue(DispatchQueue?)
        case cancelAllOperations
        case waitUntilAllOperationsAreFinished
        case operations
        case operationCount
    }

    private(set) var history = [Event]()

#if swift(>=5.1)
    @available(macOS 10.15, iOS 13.0, *)
    override var progress: Progress {
        history.append(.progress)
        return super.progress
    }
#endif // swift(>=5.1)

    override func addOperation(_ op: Operation) {
        history.append(.addOperation(op))
        super.addOperation(op)
    }

    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        history.append(.addOperations(ops, waitUntilFinished: wait))
        super.addOperations(ops, waitUntilFinished: wait)
    }

    override func addOperation(_ block: @escaping () -> Void) {
        history.append(.addBlockOperation(block))
        super.addOperation(block)
    }

#if swift(>=5.1)
    @available(macOS 10.15, iOS 13.0, *)
    override func addBarrierBlock(_ barrier: @escaping () -> Void) {
        history.append(.addBarrierBlock(barrier))
        super.addBarrierBlock(barrier)
    }
#endif // swift(>=5.1)

    override var maxConcurrentOperationCount: Int {
        get {
            history.append(.getMaxConcurrentOperationCount)
            return super.maxConcurrentOperationCount
        }
        set {
            history.append(.setMaxConcurrentOperationCount(newValue))
            super.maxConcurrentOperationCount = newValue
        }
    }

    override var isSuspended: Bool {
        get {
            history.append(.getIsSuspended)
            return super.isSuspended
        }
        set {
            history.append(.setIsSuspended(newValue))
            super.isSuspended = newValue
        }
    }

    override var name: String? {
        get {
            history.append(.getName)
            return super.name
        }
        set {
            history.append(.setName(newValue))
            super.name = newValue
        }
    }

    override var qualityOfService: QualityOfService {
        get {
            history.append(.getQualityOfService)
            return super.qualityOfService
        }
        set {
            history.append(.setQualityOfService(newValue))
            super.qualityOfService = newValue
        }
    }

    override var underlyingQueue: DispatchQueue? {
        get {
            history.append(.getUnderlyingQueue)
            return super.underlyingQueue
        }
        set {
            history.append(.setUnderlyingQueue(newValue))
            super.underlyingQueue = newValue
        }
    }

    override func cancelAllOperations() {
        history.append(.cancelAllOperations)
        super.cancelAllOperations()
    }

    override func waitUntilAllOperationsAreFinished() {
        history.append(.waitUntilAllOperationsAreFinished)
        super.waitUntilAllOperationsAreFinished()
    }

    // These properties are declared in an extension in swift-corelibs-foundation,
    // so they can't be overridden.
#if canImport(Darwin)
    override var operations: [Operation] {
        history.append(.operations)
        return super.operations
    }

    override var operationCount: Int {
        history.append(.operationCount)
        return super.operationCount
    }
#endif // canImport(Darwin)
}
