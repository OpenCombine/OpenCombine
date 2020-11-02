//
//  PropertyListEncoderTests.swift
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
final class PropertyListEncoderTests: XCTestCase {

    func testSuccessfullyEncode() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let input = [Subscribers.Completion<TestingError>.finished]
        var actualOutput: String?
        var actualCompletion: Subscribers.Completion<Error>?

        let cancellable = Just(input)
            .encode(encoder: encoder)
            .map { String(decoding: $0, as: UTF8.self) }
            .sink(receiveCompletion: { actualCompletion = $0 },
                  receiveValue: { actualOutput = $0 })

        switch actualCompletion {
        case .finished?:
            XCTAssertEqual(actualOutput, """
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

            """)
        case .failure(let error)?:
            XCTFail("Unexpected failure received: \(error)")
        case nil:
            XCTFail("Expected completion")
        }
        cancellable.cancel()
    }

    func testEncodingFailure() {
        let encoder = PropertyListEncoder()
        let input = Double.nan
        var actualOutput: String?
        var actualCompletion: Subscribers.Completion<Error>?
        let cancellable = Just(input)
            .encode(encoder: encoder)
            .map { String(decoding: $0, as: UTF8.self) }
            .sink(receiveCompletion: { actualCompletion = $0 },
                  receiveValue: { actualOutput = $0 })

        switch actualCompletion {
        case .finished?:
            XCTFail("Unexpected success")
        case .failure(EncodingError.invalidValue)?:
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
