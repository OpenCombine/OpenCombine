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

    func testEncodeWorks() {
        let testValue = TestDecodable()

        var data: Data?
        _ = Publishers
            .Just(testValue)
            .encode(encoder: jsonEncoder)
            .sink(receiveValue: { foundValue in
                data = foundValue
            })

        let decoded = try! jsonDecoder.decode(TestDecodable.self, from: data!)
        XCTAssert(decoded.identifier == testValue.identifier)
    }
}
