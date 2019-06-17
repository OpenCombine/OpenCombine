//
//  Subscription.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol representing the connection of a subscriber to a publisher.
///
/// Subcriptions are class constrained because a `Subscription` has identity -
/// defined by the moment in time a particular subscriber attached to a publisher.
/// Canceling a `Subscription` must be thread-safe.
///
/// You can only cancel a `Subscription` once.
///
/// Canceling a subscription frees up any resources previously allocated by attaching the `Subscriber`.
public protocol Subscription: Cancellable, CustomCombineIdentifierConvertible {

    /// Tells a publisher that it may send more values to the subscriber.
    func request(_ demand: Subscribers.Demand)
}

/// MARK: -
public enum Subscriptions {}

private final class Empty: Subscription, CustomStringConvertible, CustomReflectable {

    private init() {}

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {}

    var combineIdentifier: CombineIdentifier { return CombineIdentifier() }

    static let shared = Empty()

    var description: String { return "Empty" }

    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
}

extension Subscriptions {

    /// Returns the 'empty' subscription.
    ///
    /// Use the empty subscription when you need a `Subscription` that ignores requests and cancellation.
    public static var empty: Subscription { return Empty.shared }
}
