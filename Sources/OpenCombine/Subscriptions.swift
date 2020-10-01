//
//  Subscriptions.swift
//
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

/// A namespace for symbols related to subscriptions.
public enum Subscriptions {}

extension Subscriptions {

    /// Returns the “empty” subscription.
    ///
    /// Use the empty subscription when you need a `Subscription` that ignores requests
    /// and cancellation.
    public static let empty: Subscription = _EmptySubscription.singleton
}

extension Subscriptions {
    private struct _EmptySubscription: Subscription,
                                       CustomStringConvertible,
                                       CustomReflectable,
                                       CustomPlaygroundDisplayConvertible
    {
        let combineIdentifier = CombineIdentifier()

        private init() {}

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {}

        fileprivate static let singleton = _EmptySubscription()

        var description: String { return "Empty" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
