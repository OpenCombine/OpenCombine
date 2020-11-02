//
//  TestingThreadSafety.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if !WASI

import Dispatch
import Foundation
import XCTest

func race(times: Int = 100, _ bodies: () -> Void...) {
    DispatchQueue.concurrentPerform(iterations: bodies.count) {
        for _ in 0..<times {
            bodies[$0]()
        }
    }
}

final class Atomic<Value> {
    let lock = NSLock()
    private var _value: Value

    init(_ initialValue: Value) {
        _value = initialValue
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }

    func `do`(_ body: (inout Value) throws -> Void) rethrows {
        lock.lock()
        defer { lock.unlock() }
        try body(&_value)
    }
}

extension Atomic where Value: Equatable {
    static func == (lhs: Atomic<Value>, rhs: Value) -> Bool {
        return lhs.value == rhs
    }

    static func == (lhs: Value, rhs: Atomic<Value>) -> Bool {
        return rhs == lhs
    }
}

extension Atomic where Value: AdditiveArithmetic {

    static func += (lhs: Atomic<Value>, rhs: Value) {
        lhs.do { $0 += rhs }
    }

    static func -= (lhs: Atomic<Value>, rhs: Value) {
        lhs.do { $0 -= rhs }
    }
}

extension Atomic where Value: Collection {

    var count: Int {
        return value.count
    }

    var isEmpty: Bool {
        return value.isEmpty
    }

    subscript(index: Value.Index) -> Value.Element {
        return value[index]
    }

    func dropFirst(_ k: Int = 1) -> Value.SubSequence {
        return value.dropFirst(k)
    }

    func dropLast(_ k: Int = 1) -> Value.SubSequence {
        return value.dropLast(k)
    }
}

extension Atomic where Value: RangeReplaceableCollection {
    func append(_ element: Value.Element) {
        self.do {
            $0.append(element)
        }
    }
}

func XCTAssertEqual<Value: Equatable>(
    _ expression1: @autoclosure () throws -> Atomic<Value>,
    _ expression2: @autoclosure () throws -> Value,
    _ message: @autoclosure () -> String = ""
) {
    XCTAssertEqual(try expression1().value, try expression2(), message())
}

#endif // !WASI
