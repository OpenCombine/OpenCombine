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

    let encoder = TrackingEncoder()
    let decoder = JSONDecoder()

    func testDecodingFinished() throws {
        let successJSON = #"{"success":true}"#
        let illFormedSuccessJSON = #"{"error":{"description":"oops"},"success":true}"#

        XCTAssertEqual(try decoder.decode(Sut.self, from: Data(successJSON.utf8)),
                       .finished)

        XCTAssertEqual(try decoder.decode(Sut.self,
                                          from: Data(illFormedSuccessJSON.utf8)),
                       .finished)
    }

    func testDecodingFailure() {
        let failureJSON = #"{"error":{"description":"oops"},"success":false}"#
        let illFormedFailureJSON = #"{"success":false}"#

        XCTAssertEqual(try decoder.decode(Sut.self, from: Data(failureJSON.utf8)),
                       .failure(.oops))

        XCTAssertThrowsError(
            try decoder.decode(Sut.self, from: Data(illFormedFailureJSON.utf8))
        ) { error in
            switch error {
            case DecodingError.keyNotFound:
                break
            default:
                XCTFail("DecodingError.keyNotFound error expected")
            }
        }
    }

    func testEncodingFinished() throws {
        try Sut.finished.encode(to: encoder)
        XCTAssertEqual(encoder.history, [.containerKeyedBy,
                                         .keyedContainerEncodeBool(true, "success")])
    }

    func testEncodingFailure() throws {
        try Sut.failure(.oops).encode(to: encoder)
        XCTAssertEqual(encoder.history,
                       [.containerKeyedBy,
                        .keyedContainerEncodeBool(false, "success"),
                        .keyedContainerEncodeEncodable("error"),
                        .containerKeyedBy,
                        .keyedContainerEncodeString("oops", "description")])
    }
}
