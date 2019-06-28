//
//  TestingThreadSafety.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import Dispatch

func race(times: Int = 100, _ bodies: () -> Void...) {
    DispatchQueue.concurrentPerform(iterations: bodies.count) {
        for _ in 0..<times {
            bodies[$0]()
        }
    }
}

final class Atomic<Value> {
    private let _q = DispatchQueue(label: "Atomic", attributes: .concurrent)

    private var _value: Value

    init(_ initialValue: Value) {
        _value = initialValue
    }

    var value: Value {
        return _q.sync { _value }
    }

    func `do`(_ body: (inout Value) -> Void) {
        _q.sync(flags: .barrier) {
            body(&_value)
        }
    }
}
