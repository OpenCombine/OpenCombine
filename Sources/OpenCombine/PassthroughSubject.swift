//
//  PassthroughSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A subject that passes along values and completion.
///
/// Use a `PassthroughSubject` in unit tests when you want a publisher than can publish
/// specific values on-demand during tests.
public final class PassthroughSubject<Output, Failure: Error>: Subject  {

    private let _lock = Lock(recursive: true)

    private var _completion: Subscribers.Completion<Failure>?

    // TODO: Combine uses bag data structure
    private var _subscriptions: [Conduit] = []

    internal var upstreamSubscriptions: [Subscription] = []

    internal var hasAnyDownstreamDemand = false

    public init() {}

    deinit {
        for subscription in _subscriptions {
            subscription._downstream = nil
        }
    }

    public func send(subscription: Subscription) {
        _lock.do {
            upstreamSubscriptions.append(subscription)
            if hasAnyDownstreamDemand {
                subscription.request(.unlimited)
            }
        }
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        _lock.do {
            if let completion = _completion {
                subscriber.receive(subscription: Subscriptions.empty)
                subscriber.receive(completion: completion)
                return
            } else {
                let subscription = Conduit(parent: self,
                                           downstream: AnySubscriber(subscriber))

                _subscriptions.append(subscription)
                subscriber.receive(subscription: subscription)
            }
        }
    }

    public func send(_ input: Output) {
        _lock.do {
            for subscription in _subscriptions
                where !subscription._isCompleted && subscription._demand > 0
            {
                let newDemand = subscription._downstream?.receive(input) ?? .none
                subscription._demand += newDemand
                subscription._demand -= 1
            }
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        _lock.do {
            _completion = completion
            for subscriber in _subscriptions {
                subscriber._receive(completion: completion)
            }
        }
    }

    private func _acknowledgeDownstreamDemand() {
        _lock.do {
            guard !hasAnyDownstreamDemand else { return }
            hasAnyDownstreamDemand = true
            for subscription in upstreamSubscriptions {
                subscription.request(.unlimited)
            }
        }
    }
}

extension PassthroughSubject {

    fileprivate final class Conduit: Subscription {

        fileprivate var _parent: PassthroughSubject?

        fileprivate var _downstream: AnySubscriber<Output, Failure>?

        fileprivate var _demand: Subscribers.Demand = .none

        fileprivate var _isCompleted: Bool {
            return _parent == nil
        }

        fileprivate init(parent: PassthroughSubject,
                         downstream: AnySubscriber<Output, Failure>) {
            _parent = parent
            _downstream = downstream
        }

        fileprivate func _receive(completion: Subscribers.Completion<Failure>) {
            if !_isCompleted {
                _parent = nil
                _downstream?.receive(completion: completion)
            }
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            precondition(demand > 0, "demand must not be zero")
            _parent?._lock.do {
                _demand = demand
            }
            _parent?._acknowledgeDownstreamDemand()
        }

        fileprivate func cancel() {
            _parent = nil
        }
    }
}

extension PassthroughSubject.Conduit: CustomStringConvertible {
    fileprivate var description: String { return "PassthroughSubject" }
}
