//
//  Publishers.DropWhile.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Publishers {

    /// A publisher that omits elements from an upstream publisher until a given closure
    /// returns false.
    public struct DropWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that indicates whether to drop the element.
        public let predicate: (Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure, Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, predicate: catching(predicate))
            upstream.subscribe(inner)
        }
    }

    /// A publisher that omits elements from an upstream publisher until a given
    /// error-throwing closure returns false.
    public struct TryDropWhile<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that indicates whether to drop the element.
        public let predicate: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Output == Downstream.Input, Downstream.Failure == Error
        {
            let inner = Inner(downstream: subscriber, predicate: catching(predicate))
            upstream.subscribe(inner)
        }
    }
}

private class _DropWhile<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscription
    where Upstream.Output == Downstream.Input
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Predicate = (Input) -> Result<Bool, Downstream.Failure>

    /// The predicate is reset to `nil` as soon as it returns `false`.
    var predicate: Predicate?
    var isCompleted = false

    init(downstream: Downstream, predicate: @escaping Predicate) {
        self.predicate = predicate
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {

        guard upstreamSubscription != nil else {
            return .none
        }

        guard let predicate = self.predicate else {
            return downstream.receive(input)
        }

        // NOTE: until the predicate returns false, we will ask the upstream publisher
        // for elements one by one.
        //
        // However, IF the downstream requests anything, we accumulate this demand in the
        // `demand` property so that later we can provide the downstream with the correct
        // amount of values.
        //
        // As soon as the predicate returns false, we switch to the mode where
        // we just forward all the requests from the downstream to the upstream.
        switch predicate(input) {
        case .success(true):
            return .max(1)
        case .success(false):
            // Okay, we hit the first element not satisfying the predicate,
            // from now on we just republish the values to the downstream.
            self.predicate = nil
            return downstream.receive(input)
        case .failure(let error):
            downstream.receive(completion: .failure(error))
            isCompleted = true
            cancel()
            return .none
        }
    }

    func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }

    override func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
        isCompleted = true
        // Don't zero out downstream, that's what Combine does (probably a bug)
    }
}

extension Publishers.DropWhile {

    private final class Inner<Downstream: Subscriber>
        : _DropWhile<Upstream, Downstream>,
          CustomStringConvertible,
          Subscriber
        where Upstream.Output == Downstream.Input, Downstream.Failure == Upstream.Failure
    {
        var description: String { return "DropWhile" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isCompleted else { return }
            downstream.receive(completion: completion)
            isCompleted = true
        }
    }
}

extension Publishers.TryDropWhile {

    private final class Inner<Downstream: Subscriber>
        : _DropWhile<Upstream, Downstream>,
          CustomStringConvertible,
          Subscriber
        where Upstream.Output == Downstream.Input, Downstream.Failure == Error
    {
        var description: String { return "TryDropWhile" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isCompleted else { return }
            downstream.receive(completion: completion.eraseError())
            isCompleted = true
        }
    }
}

extension Publisher {

    /// Omits elements from the upstream publisher until a given closure returns false,
    /// before republishing all remaining elements.
    ///
    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value indicating whether to drop the element from the publisher’s
    ///   output.
    /// - Returns: A publisher that skips over elements until the provided closure returns
    ///   `false`.
    public func drop(
        while predicate: @escaping (Output) -> Bool
    ) -> Publishers.DropWhile<Self> {
        return Publishers.DropWhile(upstream: self, predicate: predicate)
    }

    /// Omits elements from the upstream publisher until an error-throwing closure returns
    /// false, before republishing all remaining elements.
    ///
    /// If the predicate closure throws, the publisher fails with an error.
    ///
    /// - Parameter predicate: A closure that takes an element as a parameter and returns
    ///   a Boolean value indicating whether to drop the element from the publisher’s
    ///   output.
    /// - Returns: A publisher that skips over elements until the provided closure returns
    ///   `false`, and then republishes all remaining elements. If the predicate closure
    ///   throws, the publisher fails with an error.
    public func tryDrop(
        while predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryDropWhile<Self> {
        return Publishers.TryDropWhile(upstream: self, predicate: predicate)
    }
}
