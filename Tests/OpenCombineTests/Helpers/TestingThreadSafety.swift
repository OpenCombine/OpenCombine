//
//  TestingThreadSafety.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import Dispatch

func exectuteConcurrently(times: Int = 100, _ bodies: () -> Void...) {

    let queues = bodies.indices.lazy.map {
        DispatchQueue(label: "exectuteConcurrently helper queue #\($0)")
    }

    let group = DispatchGroup()

    for (body, queue) in zip(bodies, queues) {
        queue.async(group: group) {
            for _ in 0..<times {
                body()
            }
        }
    }

    group.wait()
}

@dynamicMemberLookup
final class Atomic<T> {
    private let _q = DispatchQueue(label: "Atomic", attributes: .concurrent)

    private var _value: T

    init(_ initialValue: T) {
        _value = initialValue
    }

    var value: T {
        _q.sync { _value }
    }

    func `do`(_ body: (inout T) -> Void) {
        _q.sync(flags: .barrier) {
            body(&_value)
        }
    }

    subscript<U>(dynamicMember kp: KeyPath<T, U>) -> U {
        value[keyPath: kp]
    }
}
