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

    // TODO: Combine uses bag data structure
    private var _downstreams: [Conduit] = []

    public init() {}

    public func receive<S: Subscriber>(
        subscriber: S
    ) where Output == S.Input, Failure == S.Failure {
        let subscription = Conduit(parent: self, downstream: AnySubscriber(subscriber))
        _downstreams.append(subscription)
        subscriber.receive(subscription: subscription)
    }

    public func send(_ input: Output) {
        for subscriber in _downstreams where subscriber._demand > 0 {
            let newDemand = subscriber._downstream?.receive(input) ?? .none
            subscriber._demand += newDemand - 1
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        for subscriber in _downstreams {
            subscriber._downstream?.receive(completion: completion)
        }
    }
}

extension PassthroughSubject {

    fileprivate class Conduit: Subscription {

        var _parent: PassthroughSubject?

        var _downstream: AnySubscriber<Output, Failure>?

        var _demand: Subscribers.Demand = .none

        init(parent: PassthroughSubject, downstream: AnySubscriber<Output, Failure>) {
            _parent = parent
            _downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {
            // TODO
            _demand = demand
        }

        func cancel() {
            // TODO
            _parent = nil
            _downstream = nil
            _demand = .none
        }
    }
}
