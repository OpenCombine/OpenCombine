//
//  MapTests.swift
//
//
//  Created by Joseph Spadafora on 6/22/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class MapTests: XCTestCase {
    static let allTests = [
        ("testMapWorks", testMapWorks)
    ]

    var cancel: Cancellable?
    
    func testMapWorks() {
        let promise = XCTestExpectation(description: "map")
        let testInt = 42
        
        var mappedValue: String?
        cancel = Publishers
            .Just(testInt)
            .map(String.init)
            .sink(receiveValue: { foundValue in
                mappedValue = foundValue
                promise.fulfill()
            })
        
        wait(for: [promise], timeout: 1)
        XCTAssert(mappedValue == String(testInt))
    }
}
