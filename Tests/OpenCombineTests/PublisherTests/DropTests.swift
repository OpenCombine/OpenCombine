//
//  DropTests.swift
//
//
//  Created by Sven Weidauer on 03.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class DropTests: XCTestCase {

    func testDroppingTwoElements() {
        var received : [String] = []
        _ = AnyPublisher(["a", "b", "c"].publisher)
            .dropFirst(2)
            .sink(receiveValue: { received.append($0)})
         
        XCTAssertEqual(["c"], received, "Expect the first 2 elements to be dropped")
    }
    
    func testDroppingNothing() {
        var received : [String] = []
        _ = AnyPublisher(["a", "b", "c"].publisher)
            .dropFirst(0)
            .sink(receiveValue: { received.append($0)})
         
        XCTAssertEqual(["a", "b", "c"], received, "Expect nothing to be dropped")
    }

}
