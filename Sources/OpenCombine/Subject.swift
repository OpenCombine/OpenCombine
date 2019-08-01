//
//  Subject.swift
//  OpenCombine
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A publisher that exposes a method for outside callers to publish elements.
///
/// A subject is a publisher that you can use to ”inject” values into a stream, by calling
/// its `send()` method. This can be useful for adapting existing imperative code to the
/// Combine model.
public protocol Subject: AnyObject, Publisher {

    /// Sends a value to the subscriber.
    ///
    /// - Parameter value: The value to send.
    func send(_ value: Output)

    /// Sends a completion signal to the subscriber.
    ///
    /// - Parameter completion: A `Completion` instance which indicates whether publishing
    ///   has finished normally or failed with an error.
    func send(completion: Subscribers.Completion<Failure>)

    /// Provides this Subject an opportunity to establish demand for any new upstream
    /// subscriptions (say, via `Publisher.subscribe<S: Subject>(_: Subject)`)
    func send(subscription: Subscription)
}

extension Subject where Output == Void {

    /// Signals subscribers.
    public func send() {
        send(())
    }
}
