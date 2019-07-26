//
//  Subscriptions.swift
//
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

public enum Subscriptions {}

extension Subscriptions {

    /// Returns the 'empty' subscription.
    ///
    /// Use the empty subscription when you need a `Subscription` that ignores requests
    /// and cancellation.
    public static var empty: Subscription { return EmptySubscription.shared }
}

private final class EmptySubscription: Subscription,
                                       CustomStringConvertible,
                                       CustomReflectable
{
    private init() {}

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {}

    fileprivate static let shared = EmptySubscription()

    var description: String { return "Empty" }

    var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
}
