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
        ("testDecodeWorks", testDecodeWorks),
        ("testDownstraemReceivesFailure", testDownstreamReceivesFailure)
    ]
    
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    let testValue = TestDecodable()
    
    func testDecodeWorks() {
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
    
    func testDownstreamReceivesFailure() {
        var decodeError: Error?
        let failData = "whoops".data(using: .utf8)!
        _ = Publishers
            .Just(failData)
            .decode(type: TestDecodable.self, decoder: jsonDecoder)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error): decodeError = error
                case .finished: break
                }
            }, receiveValue: { _ in })
        XCTAssert(decodeError != nil)
    }
}
