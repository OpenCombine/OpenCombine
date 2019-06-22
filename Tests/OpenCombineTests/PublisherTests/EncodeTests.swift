//
//  EncodeTests.swift
//
//
//  Created by Joseph Spadafora on 6/21/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class EncodeTests: XCTestCase {
    static let allTests = [
        ("testEncodeWorks", testEncodeWorks)
    ]
    
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    var cancel: Cancellable?
    
    func testEncodeWorks() {
        let promise = XCTestExpectation(description: "encode")
        let testValue = TestDecodable()
        
        var data: Data?
        cancel = Publishers
            .Just(testValue)
            .encode(encoder: jsonEncoder)
            .sink(receiveValue: { foundValue in
                data = foundValue
                promise.fulfill()
            })
        
        wait(for: [promise], timeout: 1)
        let decoded = try! jsonDecoder.decode(TestDecodable.self, from: data!)
        XCTAssert(decoded.identifier == testValue.identifier)
    }
}
