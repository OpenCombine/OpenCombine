//
//  Empty.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

/// A publisher that never publishes any values, and optionally finishes immediately.
///
/// You can create a ”Never” publisher — one which never sends values and never
/// finishes or fails — with the initializer `Empty(completeImmediately: false)`.
public struct Empty<Output, Failure: Error>: Publisher, Equatable {

    /// Creates an empty publisher.
    ///
    /// - Parameter completeImmediately: A Boolean value that indicates whether
    ///   the publisher should immediately finish.
    public init(completeImmediately: Bool = true) {
        self.completeImmediately = completeImmediately
    }

    /// Creates an empty publisher with the given completion behavior and output and
    /// failure types.
    ///
    /// Use this initializer to connect the empty publisher to subscribers or other
    /// publishers that have specific output and failure types.
    /// 
    /// - Parameters:
    ///   - completeImmediately: A Boolean value that indicates whether the publisher
    ///     should immediately finish.
    ///   - outputType: The output type exposed by this publisher.
    ///   - failureType: The failure type exposed by this publisher.
    public init(completeImmediately: Bool = true,
                outputType: Output.Type,
                failureType: Failure.Type) {
        self.init(completeImmediately: completeImmediately)
    }

    /// A Boolean value that indicates whether the publisher immediately sends
    /// a completion.
    ///
    /// If `true`, the publisher finishes immediately after sending a subscription
    /// to the subscriber. If `false`, it never completes.
    public let completeImmediately: Bool

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        subscriber.receive(subscription: Subscriptions.empty)
        if completeImmediately {
            subscriber.receive(completion: .finished)
        }
    }
}
