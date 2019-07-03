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

    private var _completion: Subscribers.Completion<Failure>?

    /// The value wrapped by this subject, published as a new element whenever it changes.
    public var value: Output {
        didSet {
            send(value)
        }
    }

    /// Creates a current value subject with the given initial value.
    ///
    /// - Parameter value: The initial value to publish.
    public init(_ value: Output) {
        self.value = value
    }

    public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Output == SubscriberType.Input, Failure == SubscriberType.Failure
    {
        let subscription = Conduit(parent: self, downstream: AnySubscriber(subscriber))

        _lock.do {
            _subscriptions.append(subscription)
        }

        subscriber.receive(subscription: subscription)
    }

    public func send(_ input: Output) {
        _lock.do {
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
            guard demand > 0 else { return }
            _parent?._lock.do {
                if !_delivered, let value = _parent?.value {
                    _offer(value)
                    _demand += demand
                    _demand -= 1
                } else {
                    _demand = demand
                }
            }
        }

        func cancel() {
            _parent = nil
        }
    }
}
