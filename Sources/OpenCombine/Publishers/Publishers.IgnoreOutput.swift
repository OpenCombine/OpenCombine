//
//  Publishers.IgnoreOutput.swift
//
//  Created by Eric Patey on 16.08.2019.
//

extension Publisher {

    /// Ingores all upstream elements, but passes along a completion state (finished or
    /// failed).
    ///
    /// Use the `ignoreOutput(`` operator to determine if a publisher is able to complete
    /// successfully or would fail.
    ///
    /// In the example below, the array publisher (`numbers`) delivers the first five of
    /// its elements successfully, as indicated by the `ignoreOutput()` operator.
    /// The operator consumes, but doesn’t republish the elements downstream. However,
    /// the sixth element, `0`, causes the error throwing closure to catch
    /// a `NoZeroValuesAllowedError` that terminates the stream.
    ///
    ///     struct NoZeroValuesAllowedError: Error {}
    ///     let numbers = [1, 2, 3, 4, 5, 0, 6, 7, 8, 9]
    ///     cancellable = numbers.publisher
    ///         .tryFilter({ anInt in
    ///             guard anInt != 0 else { throw NoZeroValuesAllowedError() }
    ///             return anInt < 20
    ///         })
    ///         .ignoreOutput()
    ///         .sink(receiveCompletion: {print("completion: \($0)")},
    ///               receiveValue: {print("value \($0)")})
    ///
    ///     // Prints: "completion: failure(NoZeroValuesAllowedError())"
    ///
    /// The output type of this publisher is `Never`.
    ///
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
