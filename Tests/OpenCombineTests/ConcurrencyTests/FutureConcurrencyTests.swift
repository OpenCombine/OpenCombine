//
//  FutureConcurrencyTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 12.12.2021.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

// swiftlint:disable:next line_length
#if !os(Windows) && !os(WASI) // TEST_DISCOVERY_CONDITION
@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
final class FutureConcurrencyTests: XCTestCase {

    func testAsyncAwaitNonThrowingSuccess() async {
        var promise: Future<Int, Never>.Promise?
        let future = Future<Int, Never> { promise = $0 }

        let task = Task {
            await future.value
        }

        promise?(.success(42))

        let value = await task.value

        XCTAssertEqual(value, 42)
    }

    func testAsyncAwaitThrowingSuccess() async throws {
        var promise: Future<Int, TestingError>.Promise?
        let future = Future<Int, TestingError> { promise = $0 }

        let task = Task {
            try await future.value
        }

        promise?(.success(42))

        let value = try await task.value

        XCTAssertEqual(value, 42)
    }

    func testAsyncAwaitThrowingFailure() async throws {
        var promise: Future<Int, TestingError>.Promise?
        let future = Future<Int, TestingError> { promise = $0 }

        let task = Task { try await future.value }

        promise?(.failure(.oops))

        do {
            _ = try await task.value
            XCTFail("Expected an error")
        } catch let error as TestingError {
            XCTAssertEqual(error, .oops)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
#endif
