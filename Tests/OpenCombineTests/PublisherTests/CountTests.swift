//
//  CountTests.swift
//  
//
//  Created by Joseph Spadafora on 6/25/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class CountTests: XCTestCase {

    static let allTests = [
        ("testSendsCorrectCount", testSendsCorrectCount)
    ]

    func testSendsCorrectCount() {
        var currentCount = 0

        let publisher = PassthroughSubject<Void, Never>()
        _ = publisher
            .count()
            .sink(receiveValue: { currentCount = $0 })

        let sendAmount = Int.random(in: 1...1000)
        for _ in 0..<sendAmount {
            publisher.send()
        }

        publisher.send(completion: .finished)
        XCTAssert(currentCount == sendAmount)
    }

    func testCountWaitsUntilFinishedToSend() {
    }
}
