//
//  JSONDecoderTests.swift
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
final class JSONDecoderTests: XCTestCase {
    func testSuccessfullyDecode() {
        let decoder = JSONDecoder()
        let input = #"[{"success":true}]"#
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
        let decoder = JSONDecoder()
        let input = #"{"a":1,"b":2}"#
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

#endif // !WASI
