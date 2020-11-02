//
//  PropertyListDecoderTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

// PropertyListEncoder and PropertyListDecoder are unavailable in
// swift-corelibs-foundation prior to Swift 5.1.
#if canImport(Darwin) || swift(>=5.1) && !WASI // TEST_DISCOVERY_CONDITION

import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class PropertyListDecoderTests: XCTestCase {
    func testSuccessfullyDecode() {
        let decoder = PropertyListDecoder()
        let input = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <array>
        \t<dict>
        \t\t<key>success</key>
        \t\t<true/>
        \t</dict>
        </array>
        </plist>

        """
        var actualOutput: [Subscribers.Completion<TestingError>]?
        var actualCompletion: Subscribers.Completion<Error>?
        let cancellable = Just(input)
            .map { Data($0.utf8) }
            .decode(type: [Subscribers.Completion<TestingError>].self, decoder: decoder)
            .sink(receiveCompletion: { actualCompletion = $0 },
                  receiveValue: { actualOutput = $0 })
        switch actualCompletion {
        case .finished?:
            XCTAssertEqual(actualOutput, [.finished])
        case .failure(let error)?:
            XCTFail("Unexpected failure received: \(error)")
        case nil:
            XCTFail("Expected completion")
        }
        cancellable.cancel()
    }

    func testDecodingFailure() {
        let decoder = PropertyListDecoder()
        let input = "000000"
        var actualOutput: [Int]?
        var actualCompletion: Subscribers.Completion<Error>?
        let cancellable = Just(input)
            .map { Data($0.utf8) }
            .decode(type: [Int].self, decoder: decoder)
            .sink(receiveCompletion: { actualCompletion = $0 },
                  receiveValue: { actualOutput = $0 })
        switch actualCompletion {
        case .finished?:
            XCTFail("Unexpected success")
        case .failure(DecodingError.typeMismatch)?:
            XCTAssertNil(actualOutput)
        case .failure(let error)?:
            XCTFail("Unexpected failure received: \(error)")
        case nil:
            XCTFail("Expected completion")
        }
        cancellable.cancel()
    }
}

#endif // canImport(Darwin) || swift(>=5.1) && !WASI
