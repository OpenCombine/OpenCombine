//
//  DecodeTests.swift
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
final class DecodeTests: XCTestCase {
    static let allTests = [
        ("testDecodeWorks", testDecodeWorks)
    ]
    
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    func testDecodeWorks() {
        let testValue = TestDecodable()
        let data = try! jsonEncoder.encode(testValue)
        
        var decodedValue: TestDecodable?
        _ = Publishers
            .Just(data)
            .decode(type: TestDecodable.self, decoder: jsonDecoder)
            .sink(receiveValue: { foundValue in
                decodedValue = foundValue
            })
        
        XCTAssert(testValue.identifier == decodedValue?.identifier)
    }
}
