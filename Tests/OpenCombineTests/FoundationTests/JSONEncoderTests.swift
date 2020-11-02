//
//  JSONEncoderTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

#if !WASI

import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class JSONEncoderTests: XCTestCase {

    func testSuccessfullyEncode() {
        let encoder = JSONEncoder()
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
            XCTAssertEqual(actualOutput, #"[{"success":true}]"#)
        case .failure(let error)?:
            XCTFail("Unexpected failure received: \(error)")
        case nil:
            XCTFail("Expected completion")
        }
        cancellable.cancel()
    }

    func testEncodingFailure() {
        let encoder = JSONEncoder()
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

#endif // !WASI
