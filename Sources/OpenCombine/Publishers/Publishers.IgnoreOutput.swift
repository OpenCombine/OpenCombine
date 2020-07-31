//
//  Publishers.IgnoreOutput.swift
//
//  Created by Eric Patey on 16.08.2019.
//

extension Publisher {

    /// Ignores all upstream elements, but passes along a completion
    /// state (finished or failed).
    ///
    /// The output type of this publisher is `Never`.
    /// - Returns: A publisher that ignores all upstream elements.
    public func ignoreOutput() -> Publishers.IgnoreOutput<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {
    /// A publisher that ignores all upstream elements, but passes along a completion
    /// state (finish or failed).
    public struct IgnoreOutput<Upstream: Publisher>: Publisher {

        public typealias Output = Never

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Upstream.Failure, Downstream.Input == Never
        {
            upstream.subscribe(Inner<Downstream>(downstream: subscriber))
        }
    }
}

extension Publishers.IgnoreOutput {
    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Never, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        let combineIdentifier = CombineIdentifier()

        fileprivate init(downstream: Downstream) {
            self.downstream = downstream
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
            subscription.request(.unlimited)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        var description: String { return "IgnoreOutput" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.IgnoreOutput: Equatable where Upstream: Equatable {}
