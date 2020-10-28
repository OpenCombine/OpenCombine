//
//  TestingThreadSafety.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import Dispatch
import Foundation

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

    func `do`(_ body: (inout Value) -> Void) {
        lock.lock()
        body(&_value)
        lock.unlock()
    }
}
