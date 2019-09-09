//
//  DelayTests.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 08/09/2019.
//

import XCTest

//#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
import Darwin
//#else
//import Darwin
//import OpenCombine
//#endif

@available(iOS 13.0, *)
final class DelayTests: XCTestCase {

    static let allTests = [
        ("testDelayNotFireWhenPublisherChangesValueOnSubscribe",
         testDelayNotFireWhenPublisherChangesValueOnSubscribe),
        ("testDelayFireOnPublisherChangeValue", testDelayFireOnPublisherChangeValue),
        ("testDelayNotFireAfterCancel", testDelayNotFireAfterCancel),
        ("testDelayDurationAndValues", testDelayDurationAndValues),
        ("testTestSuiteIncludesAllTests", testTestSuiteIncludesAllTests),
    ]

    func testDelayNotFireWhenPublisherChangesValueOnSubscribe() {
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let sheduler = RunLoop.main
        let interval: RunLoop.SchedulerTimeType.Stride = 1.0
        let tolerance = sheduler.minimumTolerance

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: interval,
                                     tolerance: tolerance,
                                     scheduler: sheduler)
        let expectation = XCTestExpectation(description: #function)
        expectation.isInverted = true

        let cancel = delay.sink { _ in
            expectation.fulfill()
        }
        passthrow.send(0)

        wait(for: [expectation], timeout: 2.0)
        cancel.cancel()
    }

    func testDelayFireOnPublisherChangeValue() {
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let sheduler = RunLoop.main
        let tolerance = sheduler.minimumTolerance

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: 1.0,
                                     tolerance: tolerance,
                                     scheduler: sheduler)
        let expectation = XCTestExpectation(description: #function)

        let cancel = delay.sink { _ in
            expectation.fulfill()
        }
        sheduler.perform {
            passthrow.send(0)
        }
        wait(for: [expectation], timeout: 2.0)
        cancel.cancel()
    }

    func testDelayNotFireAfterCancel() {
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let sheduler = RunLoop.main
        let tolerance = sheduler.minimumTolerance

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: 1.0,
                                     tolerance: tolerance,
                                     scheduler: sheduler)
        let expectation = XCTestExpectation(description: #function)
        expectation.isInverted = true

        let cancel = delay.sink { _ in
            expectation.fulfill()
        }
        sheduler.perform {
             passthrow.send(0)
             cancel.cancel()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testDelayDurationAndValues() {
        struct Context {
            let time: Double
            let value: Int
        }
        func currentTime() -> Double {
            var time = timeval()
            _ = gettimeofday(&time, nil)
            let result = Double(time.tv_sec) + Double(time.tv_usec) / 1_000_000
            return result
        }
        let passthrow: PassthroughSubject<Int, Never> = PassthroughSubject()
        let sheduler = RunLoop.main
        let tolerance = sheduler.minimumTolerance
        let toleranceValue: Double = tolerance.timeInterval
        let delayTime: Double = 1.0

        let delay = Publishers.Delay(upstream: passthrow,
                                     interval: 1.0,
                                     tolerance: tolerance,
                                     scheduler: sheduler)
        let expectation = XCTestExpectation(description: #function)
        expectation.isInverted = true

        var receivedValues: [Context] = []
        let cancel = delay.sink { value in
            let received = Context(time: currentTime(), value: value)
            receivedValues.append(received)
        }
        var sentValues: [Context] = []
        // Send 1st value at start
        sheduler.perform {
            let first = Context(time: currentTime(), value: 10)
            passthrow.send(first.value)
            sentValues.append(first)
        }
        // Send 2nd value after 1 sec
        sheduler.schedule(after: sheduler.now.advanced(by: 1)) {
            let second = Context(time: currentTime(), value: 654)
            passthrow.send(second.value)
            sentValues.append(second)
        }
        // Send 3d value after 2 sec
        sheduler.schedule(after: sheduler.now.advanced(by: 2)) {
            let fird = Context(time: currentTime(), value: 82375)
            passthrow.send(fird.value)
            sentValues.append(fird)
        }
        wait(for: [expectation], timeout: 5.0)
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

    // MARK: -
    func testTestSuiteIncludesAllTests() {
        // https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let thisClass = type(of: self)
        let allTestsCount = thisClass.allTests.count
        let darwinCount = thisClass.defaultTestSuite.testCaseCount
        XCTAssertEqual(allTestsCount,
                       darwinCount,
                       "\(darwinCount - allTestsCount) tests are missing from allTests")
#endif
        }
}
