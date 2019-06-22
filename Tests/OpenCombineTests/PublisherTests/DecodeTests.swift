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
    
    var cancel: Cancellable?
    
    func testDecodeWorks() {
        let promise = XCTestExpectation(description: "decode")
        let testValue = TestDecodable()
        let data = try! jsonEncoder.encode(testValue)
        
        var decodedValue: TestDecodable?
        cancel = Publishers
            .Just(data)
            .decode(type: TestDecodable.self, decoder: jsonDecoder)
            .sink(receiveValue: { foundValue in
                decodedValue = foundValue
                promise.fulfill()
            })
        
        wait(for: [promise], timeout: 1)
        XCTAssert(testValue.identifier == decodedValue?.identifier)
    }
}

private struct TestDecodable: Codable, Equatable {
    let identifier: String
}

extension TestDecodable {
    init() {
        self.identifier = UUID().uuidString
    }
}

extension JSONDecoder: TopLevelDecoder {}
