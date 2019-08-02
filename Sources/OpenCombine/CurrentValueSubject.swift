//
//  CurrentValueSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A subject that wraps a single value and publishes a new element whenever the value
/// changes.
public final class CurrentValueSubject<Output, Failure: Error>: Subject {

    private let _lock = Lock(recursive: true)

    // TODO: Combine uses bag data structure
    private var _subscriptions: [Conduit] = []

    private var _value: Output

    private var _completion: Subscribers.Completion<Failure>?

    internal var upstreamSubscriptions: [Subscription] = []

    internal var hasAnyDownstreamDemand = false

    /// The value wrapped by this subject, published as a new element whenever it changes.
    public var value: Output {
        get {
            return _value
        }
        set {
            send(newValue)
        }
    }

    /// Creates a current value subject with the given initial value.
    ///
    /// - Parameter value: The initial value to publish.
    public init(_ value: Output) {
        self._value = value
    }

    deinit {
        for subscription in _subscriptions {
            subscription._downstream = nil
        }
    }

    public func send(subscription: Subscription) {
        _lock.do {
            upstreamSubscriptions.append(subscription)
            subscription.request(.unlimited)
        }
    }

    public func receive<Subscriber: OpenCombine.Subscriber>(subscriber: Subscriber)
        where Output == Subscriber.Input, Failure == Subscriber.Failure
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
            _value = input
            for subscription in _subscriptions where !subscription.isCompleted {
                if subscription._demand > 0 {
                    subscription._offer(input)
                    subscription._demand -= 1
                } else {
                    subscription._delivered = false
                }
            }
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        _completion = completion
        _lock.do {
            for subscriber in _subscriptions {
                subscriber._receive(completion: completion)
            }
        }
    }
}

extension CurrentValueSubject {

    fileprivate class Conduit: Subscription {

        fileprivate var _parent: CurrentValueSubject?

        fileprivate var _downstream: AnySubscriber<Output, Failure>?

        fileprivate var _demand: Subscribers.Demand = .none

        /// Whethere we satisfied the demand
        fileprivate var _delivered = false

        var isCompleted: Bool {
            return _parent == nil
        }

        fileprivate func _offer(_ value: Output) {
            let newDemand = _downstream?.receive(value) ?? .none
            _demand += newDemand
            _delivered = true
        }

        fileprivate init(parent: CurrentValueSubject,
                         downstream: AnySubscriber<Output, Failure>) {
            _parent = parent
            _downstream = downstream
        }

        fileprivate func _receive(completion: Subscribers.Completion<Failure>) {
            if !isCompleted {
                _parent = nil
                _downstream?.receive(completion: completion)
            }
        }

        func request(_ demand: Subscribers.Demand) {
            precondition(demand > 0)
            _parent?._lock.do {
                if !_delivered, let value = _parent?.value {
                    _offer(value)
                    _demand += demand
                    _demand -= 1
                } else {
                    _demand = demand
                }
                _parent?.hasAnyDownstreamDemand = true
            }
        }

        func cancel() {
            _parent = nil
        }
    }
}

extension CurrentValueSubject.Conduit: CustomStringConvertible {
    fileprivate var description: String { return "CurrentValueSubject" }
}
