//
//  FutureTests.swift
//  
//
//  Created by Max Desiatov on 24/11/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class FutureTests: XCTestCase {
    struct TestError: Error {}

    func testFutureSuccess() {
        var isCompleted = false
        var outputValue = false
        var promise: Future<Bool, Never>.Promise?

        let future = Future<Bool, Never> { promise = $0 }

        let cancellable = future.sink(receiveCompletion: { _ in
            isCompleted = true
        }, receiveValue: { value in
            outputValue = value
        })

        promise?(.success(true))

        XCTAssertTrue(isCompleted)
        XCTAssertTrue(outputValue)
        XCTAssertNotNil(cancellable)
    }

    func testFutureFailure() {
        var error: TestError?
        var promise: Future<Bool, TestError>.Promise?

        let future = Future<Bool, TestError> { promise = $0 }

        let cancellable = future.sink(receiveCompletion: {
            guard case let .failure(e) = $0 else { return }

            error = e
        }, receiveValue: { _ in
            XCTFail("no value should be returned")
        })

        promise?(.failure(TestError()))

        XCTAssertNotNil(error)
        XCTAssertNotNil(cancellable)
    }

    func testFutureWithinFlatMap() {
        var isCompleted = false
        let simplePublisher = PassthroughSubject<String, Never>()
        var promise: (() -> ())?
        var outputValue: String?

        let cancellable = simplePublisher
            .flatMap { name in
                Future<String, Never> { fulfill in
                    promise = { fulfill(.success(name)) }
                }.map { "\($0) foo" }
            }
            .sink(receiveCompletion: { err in
                isCompleted = true
            }, receiveValue: { value in
                outputValue = value
            })

        XCTAssertNil(outputValue)
        simplePublisher.send("one")
        promise?()

        XCTAssertEqual(outputValue, "one foo")

        simplePublisher.send(completion: .finished)
        XCTAssertTrue(isCompleted)
        XCTAssertNotNil(cancellable)
    }

    func testResolvingMultipleTimes() {
        var isCompleted = false
        var outputValue = false
        var promise: Future<Bool, Never>.Promise?

        let future = Future<Bool, Never> { promise = $0 }

        let cancellable = future.sink(receiveCompletion: { _ in
            isCompleted = true
        }, receiveValue: { value in
            outputValue = value
        })

        promise?(.success(true))

        XCTAssertTrue(isCompleted)
        XCTAssertTrue(outputValue)
        XCTAssertNotNil(cancellable)

        promise?(.success(false))

        XCTAssertTrue(isCompleted)
        XCTAssertTrue(outputValue)
        XCTAssertNotNil(cancellable)
    }

    func testCancellation() {
        var isCompleted = false
        var outputValue = false
        var promise: Future<Bool, Never>.Promise?

        let future = Future<Bool, Never> { promise = $0 }

        let cancellable = future.sink(receiveCompletion: { _ in
            isCompleted = true
        }, receiveValue: { value in
            outputValue = value
        })

        cancellable.cancel()

        promise?(.success(true))

        XCTAssertFalse(isCompleted)
        XCTAssertFalse(outputValue)
        XCTAssertNotNil(cancellable)
    }

    func testCancellationViaDeinit() {
        var isCompleted = false
        var outputValue = false
        var promise: Future<Bool, Never>.Promise?

        let future = Future<Bool, Never> { promise = $0 }

        var cancellable: AnyCancellable? = future.sink(receiveCompletion: { _ in
            isCompleted = true
        }, receiveValue: { value in
            outputValue = value
        })

        XCTAssertNotNil(cancellable)

        cancellable = nil

        promise?(.success(true))

        XCTAssertFalse(isCompleted)
        XCTAssertFalse(outputValue)
    }
}
