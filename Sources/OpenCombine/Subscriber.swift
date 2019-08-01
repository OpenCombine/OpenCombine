//
//  Subscriber.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol that declares a type that can receive input from a publisher.
public protocol Subscriber: CustomCombineIdentifierConvertible {

    /// The kind of values this subscriber receives.
    associatedtype Input

    /// The kind of errors this subscriber might receive.
    ///
    /// Use `Never` if this `Subscriber` cannot receive errors.
    associatedtype Failure: Error

    /// Tells the subscriber that it has successfully subscribed to the publisher and may
    /// request items.
    ///
    /// Use the received `Subscription` to request items from the publisher.
    /// - Parameter subscription: A subscription that represents the connection between
    ///   publisher and subscriber.
    func receive(subscription: Subscription)

    /// Tells the subscriber that the publisher has produced an element.
    ///
    /// - Parameter input: The published element.
    /// - Returns: A `Demand` instance indicating how many more elements the subcriber
    ///   expects to receive.
    func receive(_ input: Input) -> Subscribers.Demand

    /// Tells the subscriber that the publisher has completed publishing, either normally
    /// or with an error.
    ///
    /// - Parameter completion: A `Completion` case indicating whether publishing
    ///   completed normally or with an error.
    func receive(completion: Subscribers.Completion<Failure>)
}

extension Subscriber where Input == Void {

    public func receive() -> Subscribers.Demand {
        return receive(())
    }
}

extension Optional where Wrapped: Subscriber {

    internal func receive(subscription: Subscription) {
        self?.receive(subscription: subscription)
    }

    internal func receive(_ input: Wrapped.Input) -> Subscribers.Demand {
        return self?.receive(input) ?? .none
    }

    internal func receive(completion: Subscribers.Completion<Wrapped.Failure>) {
        self?.receive(completion: completion)
    }
}
