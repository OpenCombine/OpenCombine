//
//  PassthroughSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import Foundation

/// A subject that passes along values and completion.
///
/// Use a `PassthroughSubject` in unit tests when you want a publisher than can publish specific values on-demand
/// during tests.
public final class PassthroughSubject<Output, Failure: Error>: Subject  {

    private let _lock = Lock(recursive: true)

    private var _completion: Subscribers.Completion<Failure>?

    // TODO: Combine uses bag data structure
    private var _downstreams: [Conduit] = []

    public init() {}

    public func receive<S: Subscriber>(
        subscriber: S
    ) where Output == S.Input, Failure == S.Failure {
        let subscription = Conduit(parent: self, downstream: AnySubscriber(subscriber))

        _lock.do {
            _downstreams.append(subscription)
        }

        subscriber.receive(subscription: subscription)
    }

    public func send(_ input: Output) {
        _lock.do {
            for subscriber in _downstreams where subscriber._demand > 0 {
                let newDemand = subscriber._downstream?.receive(input) ?? .none
                subscriber._demand += newDemand - 1
            }
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        _completion = completion
        _lock.do {
            for subscriber in _downstreams {
                subscriber._receive(completion: completion)
            }
        }
    }
}

extension PassthroughSubject {

    fileprivate class Conduit: Subscription {

        fileprivate var _parent: PassthroughSubject?

        fileprivate var _downstream: AnySubscriber<Output, Failure>?

        fileprivate var _demand: Subscribers.Demand = .none

        fileprivate init(parent: PassthroughSubject,
                         downstream: AnySubscriber<Output, Failure>) {
            _parent = parent
            _downstream = downstream
        }

        fileprivate func _receive(completion: Subscribers.Completion<Failure>) {
            let downstream = _downstream
            cancel()
            downstream?.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            _parent?._lock.do {
                _demand = demand
            }
        }

        func cancel() {
            _parent = nil
            _downstream = nil
        }
    }
}
