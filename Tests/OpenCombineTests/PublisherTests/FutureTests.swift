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
    enum TestFailureCondition: Error {
        case anErrorExample
    }

    // example of a asynchronous function to be called from within a Future and its completion closure
    func asyncAPICall(sabotage: Bool, completion completionBlock: @escaping ((Bool, Error?) -> Void)) {
        DispatchQueue.global(qos: .background).async {
            let delay = Int.random(in: 1...3)
            print(" * making async call (delay of \(delay) seconds)")
            sleep(UInt32(delay))
            if sabotage {
                completionBlock(false, TestFailureCondition.anErrorExample)
            }
            completionBlock(true, nil)
        }
    }

    func testFuturePublisher() {
        // setup
        var outputValue: Bool = false
        let expectation = XCTestExpectation(description: self.debugDescription)

        // the creating the future publisher
        let sut = Future<Bool, Error> { promise in
            self.asyncAPICall(sabotage: false) { (grantedAccess, err) in
                if let err = err {
                    promise(.failure(err))
                }
                promise(.success(grantedAccess))
            }
        }

        // driving it by attaching it to .sink
        let cancellable = sut.sink(receiveCompletion: { err in
            print(".sink() received the completion: ", String(describing: err))
            expectation.fulfill()
        }, receiveValue: { value in
            print(".sink() received value: ", value)
            outputValue = value
        })

        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(outputValue)
        XCTAssertNotNil(cancellable)
    }

    func testFuturePublisherShowingFailure() {
        // setup
        let expectation = XCTestExpectation(description: self.debugDescription)

        // the creating the future publisher
        let sut = Future<Bool, Error> { promise in
            self.asyncAPICall(sabotage: true) { (grantedAccess, err) in
                if let err = err {
                    promise(.failure(err))
                }
                promise(.success(grantedAccess))
            }
        }

        // driving it by attaching it to .sink
        let cancellable = sut.sink(receiveCompletion: { err in
            print(".sink() received the completion: ", String(describing: err))
            XCTAssertNotNil(err)
            expectation.fulfill()
        }, receiveValue: { value in
            print(".sink() received value: ", value)
            XCTFail("no value should be returned")
        })

        wait(for: [expectation], timeout: 5.0)
        XCTAssertNotNil(cancellable)
    }

    func testFutureWithinAFlatMap() {
        let simplePublisher = PassthroughSubject<String, Never>()
        var outputValue: String? = nil

        let cancellable = simplePublisher
            .print(self.debugDescription)
            .flatMap { name in
                return Future<String, Never> { promise in
                    promise(.success(name))
                }.map { result in
                    return "\(result) foo"
                }
            }
            .sink(receiveCompletion: { err in
                print(".sink() received the completion", String(describing: err))
            }, receiveValue: { value in
                print(".sink() received \(String(describing: value))")
                outputValue = value
            })

        XCTAssertNil(outputValue)
        simplePublisher.send("one")
        XCTAssertEqual(outputValue, "one foo")
        XCTAssertNotNil(cancellable)
    }
}
