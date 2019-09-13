//
//  AssignTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 15.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class AssignTests: XCTestCase {

    private typealias Sut<Root> = Subscribers.Assign<Root, Int>

    private final class TestObject {

        var value: Int = 0

        init() {}
    }

    func testDescription() {
        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        XCTAssertEqual(assign.description, "Assign TestObject.")
        XCTAssertEqual(assign.playgroundDescription as? String, "Assign TestObject.")
    }

    func testReflection() {
        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        let children = Array(assign.customMirror.children)

        XCTAssertEqual(children.count, 3)

        guard children.count == 3 else { return }

        XCTAssertEqual(children[0].label, "object")
        XCTAssert(children[0].value as? TestObject === object)

        XCTAssertEqual(children[1].label, "keyPath")
        XCTAssertEqual(children[1].value as? ReferenceWritableKeyPath<TestObject, Int>,
                       \.value)

        XCTAssertEqual(children[2].label, "status")
        XCTAssertNotNil(children[2].value)
    }

    func testSubscription() {

        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)

        let subscription1 = CustomSubscription()
        assign.receive(subscription: subscription1)
        XCTAssertEqual(subscription1.lastRequested, .unlimited)
        XCTAssertFalse(subscription1.cancelled)

        let subscription2 = CustomSubscription()
        assign.receive(subscription: subscription2)
        XCTAssertFalse(subscription1.cancelled)
        XCTAssertTrue(subscription2.cancelled)

        assign.receive(subscription: subscription1)
        XCTAssertTrue(subscription1.cancelled)

        subscription1.cancelled = false
        assign.receive(completion: .finished)
        XCTAssertTrue(subscription1.cancelled)
    }

    func testReceiveValue() {
        let object = TestObject()
        let assign = Sut(object: object, keyPath: \.value)
        let publisher = PassthroughSubject<Int, Never>()

        XCTAssertEqual(assign.receive(12), .none)
        XCTAssertEqual(object.value, 0)

        publisher.subscribe(assign)
        publisher.send(42)
        XCTAssertEqual(object.value, 42)

        publisher.send(completion: .finished)
        XCTAssertEqual(object.value, 42)

        XCTAssertEqual(assign.receive(100), .none)
        XCTAssertEqual(object.value, 42)

        publisher.subscribe(assign)
        publisher.send(1000000)
        XCTAssertEqual(object.value, 42)
    }

    func testPublisherOperator() {
        let object = TestObject()
        let publisher = PassthroughSubject<Int, Never>()

        let cancelable = publisher.assign(to: \.value, on: object)
        XCTAssertEqual(object.value, 0)

        publisher.send(42)
        XCTAssertEqual(object.value, 42)

        cancelable.cancel()
        publisher.send(1)
        XCTAssertEqual(object.value, 42)

        do {
            _ = publisher.assign(to: \.value, on: object)
        }

        publisher.send(100)
        XCTAssertEqual(object.value, 42)
    }
}
