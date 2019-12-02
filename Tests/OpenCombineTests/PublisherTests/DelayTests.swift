//
//  DelayTests.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 08/09/2019.
//

import XCTest

import OpenCombine

@available(iOS 13.0, *)
final class DelayTests: XCTestCase {

    func testDelayNotFireWhenPublisherChangesValueOnSubscribe() {
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let scheduler = VirtualTimeScheduler()
        let interval: VirtualTimeScheduler.SchedulerTimeType.Stride = 1.0
        let tolerance = scheduler.minimumTolerance

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: interval,
                                     tolerance: tolerance,
                                     scheduler: scheduler)
        var expectation = false

        let cancel = delay.sink { _ in
            expectation = true
        }
        passthrow.send(0)
        scheduler.flush()
        XCTAssertFalse(expectation)
        cancel.cancel()
    }

    func testDelayFireOnPublisherChangeValue() {
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let scheduler = VirtualTimeScheduler()
        let tolerance = scheduler.minimumTolerance

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: 1.0,
                                     tolerance: tolerance,
                                     scheduler: scheduler)
        var expectation = false

        let cancel = delay.sink { _ in
            expectation = true
        }
        scheduler.schedule {
            passthrow.send(0)
        }
        scheduler.flush()
        XCTAssertTrue(expectation)
        cancel.cancel()
    }

    func testDelayNotFireAfterCancel() {
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let scheduler = VirtualTimeScheduler()
        let tolerance = scheduler.minimumTolerance

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: 1.0,
                                     tolerance: tolerance,
                                     scheduler: scheduler)
        var expectation = false

        let cancel = delay.sink { _ in
            expectation = true
        }
        scheduler.schedule {
             cancel.cancel()
             passthrow.send(0)
        }
        scheduler.flush()
        XCTAssertFalse(expectation)
    }

    func testDelayDurationAndValues() {
        struct Context {
            let time: Double
            let value: Int
        }
        let scheduler = VirtualTimeScheduler()
        func currentTime() -> Double {
            return Double(scheduler.now.date)
        }
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let tolerance = scheduler.minimumTolerance
        let toleranceValue: Double = Double(tolerance.magnitude)
        let delayTime: Double = 1.0

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: 1.0,
                                     tolerance: tolerance,
                                     scheduler: scheduler)

        var receivedValues: [Context] = []
        let cancel = delay.sink { value in
            let received = Context(time: currentTime(), value: value)
            receivedValues.append(received)
        }
        var sentValues: [Context] = []
        // Send 1st value at start
        scheduler.schedule {
            let first = Context(time: currentTime(), value: 10)
            passthrow.send(first.value)
            sentValues.append(first)
        }
        // Send 2nd value after 1 sec
        scheduler.schedule(after: scheduler.now.advanced(by: 1)) {
            let second = Context(time: currentTime(), value: 654)
            passthrow.send(second.value)
            sentValues.append(second)
        }
        // Send 3d value after 2 sec
        scheduler.schedule(after: scheduler.now.advanced(by: 2)) {
            let fird = Context(time: currentTime(), value: 82375)
            passthrow.send(fird.value)
            sentValues.append(fird)
        }

        scheduler.flush()
        cancel.cancel()

        XCTAssertTrue(sentValues.count == 3)
        XCTAssertTrue(receivedValues.count == 3)

        if sentValues.count == 3, receivedValues.count == 3 {
            // Check values
            XCTAssertTrue(sentValues[0].value == receivedValues[0].value)
            XCTAssertTrue(sentValues[1].value == receivedValues[1].value)
            XCTAssertTrue(sentValues[2].value == receivedValues[2].value)

            let min = delayTime
            // 0.005 - error of time calculation
            let max = delayTime + toleranceValue + 0.005
            let delay1 = receivedValues[0].time - sentValues[0].time
            XCTAssertTrue(delay1 >= min && delay1 < max)

            let delay2 = receivedValues[1].time - sentValues[1].time
            XCTAssertTrue(delay2 >= min && delay1 < max)

            let delay3 = receivedValues[2].time - sentValues[2].time
            XCTAssertTrue(delay3 >= min && delay1 < max)
        }
    }
}
