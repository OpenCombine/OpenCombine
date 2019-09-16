//
//  Publishers.First.swift
//  
//
//  Created by Joseph Spadafora on 7/8/19.
//

extension Publisher {

    /// Publishes the first element of a stream, then finishes.
    ///
    /// If this publisher doesn’t receive any elements, it finishes without publishing.
    /// - Returns: A publisher that only publishes the first element of a stream.
    public func first() -> Publishers.First<Self> {
        return .init(upstream: self)
    }

    /// Publishes the first element of a stream to
    /// satisfy a predicate closure, then finishes.
    ///
    /// The publisher ignores all elements after the first.
    /// If this publisher doesn’t receive any elements,
    /// it finishes without publishing.
    /// - Parameter predicate: A closure that takes an element as a parameter and
    ///   returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream
    ///   that satifies the predicate.
    public func first(
        where predicate: @escaping (Output) -> Bool
    ) -> Publishers.FirstWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes the first element of a stream to satisfy a
    /// throwing predicate closure, then finishes.
    ///
    /// The publisher ignores all elements after the first. If this publisher
    /// doesn’t receive any elements, it finishes without publishing. If the
    /// predicate closure throws, the publisher fails with an error.
    /// - Parameter predicate: A closure that takes an element as a parameter and
    ///   returns a Boolean value that indicates whether to publish the element.
    /// - Returns: A publisher that only publishes the first element of a stream
    ///   that satifies the predicate.
    public func tryFirst(
        where predicate: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFirstWhere<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that publishes the first element of a stream, then finishes.
    public struct First<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, predicate: { _ in .success(true) })
            upstream.receive(subscriber: inner)
        }
    }

    /// A publisher that only publishes the first element of a
    /// stream to satisfy a predicate closure.
    public struct FirstWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that determines whether to publish an element.
        public let predicate: (Output) -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, predicate: catching(predicate))
            upstream.receive(subscriber: inner)
        }
    }

    /// A publisher that only publishes the first element of a stream
    /// to satisfy a throwing predicate closure.
    public struct TryFirstWhere<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The error-throwing closure that determines whether to publish an element.
        public let predicate: (Output) throws -> Bool

        public init(upstream: Upstream, predicate: @escaping (Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber, predicate: catching(predicate))
            upstream.receive(subscriber: inner)
        }
    }
}

extension Publishers.First: Equatable where Upstream: Equatable {}

private class _FirstWhere<Upstream: Publisher, Downstream: Subscriber>
    : OperatorSubscription<Downstream>,
      Subscription
    where Downstream.Input == Upstream.Output
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    typealias Predicate = (Input) -> Result<Bool, Downstream.Failure>

    //                         ┌──────────────────┐
    //                 ┌──────▶│ .pending(input)  │───────────┐
    //                 │       └──────────────────┘           │
    //   receive(input)│                                      │request(demand)
    //                 │                                      │
    //                 │                                      │
    //                 │                                      ▼
    //       ┌──────────────────┐                     ┌──────────────┐
    //  ●───▶│.waitingForDemand │                     │  .finished   │
    //       └──────────────────┘                     └──────────────┘
    //                 │                                      ▲
    //                 │                                      │
    //                 │                                      │
    //  request(demand)│                                      │receive(input)
    //                 │    ┌──────────────────────────┐      │
    //                 └───▶│ .downstreamHasRequested  │──────┘
    //                      └──────────────────────────┘
    enum State {
        case waitingForDemand
        case pending(Input)
        case downstreamHasRequested
        case finished
    }

    var predicate: Predicate?
    private var _state: State = .waitingForDemand

    var isCompleted: Bool {
        return predicate == nil
    }

    init(downstream: Downstream, predicate: @escaping Predicate) {
        self.predicate = predicate
        super.init(downstream: downstream)
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        subscription.request(.unlimited)
        downstream.receive(subscription: self)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        switch _state {
        case .pending, .finished:
            break
        case .downstreamHasRequested:
            _ifSatisfiesPredicate(input) {
                _state = .finished
                _sendDownstream(input)
            }
        case .waitingForDemand:
            _ifSatisfiesPredicate(input) {
                _state = .pending(input)
            }
        }
        return .none
    }

    private func _ifSatisfiesPredicate(_ input: Input, _ onSuccess: () -> Void) {
        guard let predicate = self.predicate else { return }
        switch predicate(input) {
        case .success(true):
            onSuccess()
        case .success(false):
            return
        case .failure(let error):
            cancel()
            downstream.receive(completion: .failure(error))
            return
        }
    }

    private func _sendDownstream(_ input: Input) {
        _ = downstream.receive(input)
        cancel()
        downstream.receive(completion: .finished)
    }

    func request(_ demand: Subscribers.Demand) {
        precondition(demand > 0, "demand must not be zero")
        switch _state {
        case .waitingForDemand:
            _state = .downstreamHasRequested
        case .pending(let input):
            _state = .finished
            _sendDownstream(input)
        case .finished, .downstreamHasRequested:
            break
        }
    }

    override func cancel() {
        predicate = nil
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
    }
}

extension Publishers.First {
    private final class Inner<Downstream: Subscriber>
        : _FirstWhere<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure
    {
        var description: String { return "First" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isCompleted else { return }
            predicate = nil
            downstream.receive(completion: completion)
        }
    }
}

extension Publishers.FirstWhere {
    private final class Inner<Downstream: Subscriber>
        : _FirstWhere<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Upstream.Output == Downstream.Input,
              Upstream.Failure == Downstream.Failure
    {
        var description: String { return "TryFirst" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isCompleted else { return }
            predicate = nil
            downstream.receive(completion: completion)
        }
    }
}

extension Publishers.TryFirstWhere {
    private final class Inner<Downstream: Subscriber>
        : _FirstWhere<Upstream, Downstream>,
          Subscriber,
          CustomStringConvertible
        where Upstream.Output == Downstream.Input,
              Downstream.Failure == Error
    {
        var description: String { return "TryFirstWhere" }

        func receive(completion: Subscribers.Completion<Failure>) {
            guard !isCompleted else { return }
            predicate = nil
            downstream.receive(completion: completion.eraseError())
        }
    }
}
