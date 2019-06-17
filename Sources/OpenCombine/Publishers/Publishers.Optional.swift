//
//  Publishers.Optional.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Publishers {

    /// A publisher that publishes an optional value to each subscriber exactly once, if the optional has a value.
    ///
    /// If `result` is `.success`, and the value is non-nil, then `Optional` waits until receiving a request for
    /// at least 1 value before sending the output. If `result` is `.failure`, then `Optional` sends the failure
    /// immediately upon subscription. If `result` is `.success` and the value is nil, then `Optional` sends
    /// `.finished` immediately upon subscription.
    ///
    /// In contrast with `Just`, an `Optional` publisher can send an error.
    /// In contrast with `Once`, an `Optional` publisher can send zero values and finish normally, or send
    /// zero values and fail with an error.
    public struct Optional<Output, Failure: Error>: Publisher {

        /// The result to deliver to each subscriber.
        public let result: Result<Output?, Failure>

        /// Creates a publisher to emit the optional value of a successful result, or fail with an error.
        ///
        /// - Parameter result: The result to deliver to each subscriber.
        public init(_ result: Result<Output?, Failure>) {
            self.result = result
        }

        public init(_ output: Output?) {
            self.init(.success(output))
        }

        public init(_ failure: Failure) {
            self.init(.failure(failure))
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S: Subscriber>(subscriber: S)
            where Output == S.Input, Failure == S.Failure
        {
            
        }
    }
}
