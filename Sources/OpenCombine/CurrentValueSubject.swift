//
//  CurrentValueSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A subject that wraps a single value and publishes a new element whenever the value changes.
public final class CurrentValueSubject<Output, Failure: Error>: Subject {

    private let _lock = Lock(recursive: true)

    // TODO: Combine uses bag data structure
    private var _downstreams: [Conduit] = []

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
            _downstreams.append(subscription)
        }

        subscriber.receive(subscription: subscription)
    }

    public func send(_ input: Output) {
        _lock.do {
            for subscriber in _downstreams {
                if subscriber._demand > 0 {
                    let newDemand = subscriber._downstream?.receive(input) ?? .none
                    subscriber._demand += newDemand - 1
                } else {
                    subscriber._delivered = false
                }
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

extension CurrentValueSubject {

    fileprivate class Conduit: Subscription {

        fileprivate var _parent: CurrentValueSubject?

        fileprivate var _downstream: AnySubscriber<Output, Failure>?

        fileprivate var _demand: Subscribers.Demand = .none

        /// Whethere we satisfied the demand
        fileprivate var _delivered = false

        fileprivate init(parent: CurrentValueSubject,
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
                if !_delivered, let value = _parent?.value {
                    let newDemand = _downstream?.receive(value) ?? .none
                    _demand = demand + newDemand - 1
                    _delivered = true
                } else {
                    _demand = demand
                }
            }
        }

        func cancel() {
            _parent = nil
            _downstream = nil
        }
    }
}
