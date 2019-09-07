//
//  CompletionTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.07.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

import Foundation

@available(macOS 10.15, iOS 13.0, *)
final class CompletionTests: XCTestCase {

    private typealias Sut = Subscribers.Completion<TestingError>

    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    let decoder = JSONDecoder()

    func testEncodingDecoding() throws {
        let successJSON = #"{"success":true}"#
        let failureJSON = #"{"error":{"description":"oops"},"success":false}"#
        let illFormedSuccessJSON = #"{"error":{"description":"oops"},"success":true}"#
        let illFormedFailureJSON = #"{"success":false}"#

        XCTAssertEqual(try String(decoding: encoder.encode(Sut.finished),
                                  as: UTF8.self),
                       successJSON)

        XCTAssertEqual(try String(decoding: encoder.encode(Sut.failure(.oops)),
                                  as: UTF8.self),
                       failureJSON)

        XCTAssertEqual(try decoder.decode(Sut.self, from: Data(successJSON.utf8)),
                       .finished)

        XCTAssertEqual(try decoder.decode(Sut.self, from: Data(failureJSON.utf8)),
                       .failure(.oops))

        XCTAssertEqual(try decoder.decode(Sut.self,
                                          from: Data(illFormedSuccessJSON.utf8)),
                       .finished)

        XCTAssertThrowsError(try decoder.decode(Sut.self,
                                                from: Data(illFormedFailureJSON.utf8)))
        { error in
            switch error {
            case DecodingError.keyNotFound:
                break
            default:
                XCTFail("DecodingError.keyNotFound error expected")
            }
        }
    }
}
