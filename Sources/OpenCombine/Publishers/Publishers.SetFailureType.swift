//
//  Publishers.SetFailureType.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.07.2019.
//

extension Publishers {

    /// A publisher that appears to send a specified failure type.
    ///
    /// The publisher cannot actually fail with the specified type and instead
    /// just finishes normally. Use this publisher type when you need to match
    /// the error types for two mismatched publishers.
    public struct SetFailureType<Upstream: Publisher, Failure: Error>: Publisher
        where Upstream.Failure == Never
    {
        public typealias Output = Upstream.Output

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// Creates a publisher that appears to send a specified failure type.
        ///
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }

        public func setFailureType<NewFailure: Error>(
            to failure: NewFailure.Type
        ) -> Publishers.SetFailureType<Upstream, NewFailure> {
            return .init(upstream: upstream)
        }
    }
}

extension Publishers.SetFailureType: Equatable where Upstream: Equatable {}

extension Publisher where Failure == Never {

    /// Changes the failure type declared by the upstream publisher.
    ///
    /// The publisher returned by this method cannot actually fail
    /// with the specified type and instead just finishes normally. Instead, you use
    /// this method when you need to match the error types of two mismatched publishers.
    ///
    /// - Parameter failureType: The `Failure` type presented by this publisher.
    /// - Returns: A publisher that appears to send the specified failure type.
    public func setFailureType<NewFailure: Error>(
        to failureType: NewFailure.Type
    ) -> Publishers.SetFailureType<Self, NewFailure> {
        return .init(upstream: self)
    }
}

extension Publishers.SetFailureType {
    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input, Failure == Downstream.Failure
    {
        private let downstream: Downstream
        let combineIdentifier = CombineIdentifier()

        fileprivate init(downstream: Downstream) {
            self.downstream = downstream
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Never>) {
            downstream.receive(completion: .finished)
        }

        var description: String { return "SetFailureType" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
