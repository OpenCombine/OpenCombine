//
//  Subscribers.Sink.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Subscribers {

    /// A simple subscriber that requests an unlimited number of values upon subscription.
    public final class Sink<Input, Failure: Error>
        : Subscriber,
          Cancellable,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    {
        /// The closure to execute on receipt of a value.
        public let receiveValue: (Input) -> Void

        /// The closure to execute on completion.
        public let receiveCompletion: (Subscribers.Completion<Failure>) -> Void

        private var _upstreamSubscription: Subscription?

        public var description: String { return "Sink" }

        public var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        public var playgroundDescription: Any { return description }

        /// Initializes a sink with the provided closures.
        ///
        /// - Parameters:
        ///   - receiveValue: The closure to execute on receipt of a value. If `nil`,
        ///     the sink uses an empty closure.
        ///   - receiveCompletion: The closure to execute on completion. If `nil`,
        ///     the sink uses an empty closure.
        public init(receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
                    receiveValue: @escaping ((Input) -> Void)) {
            self.receiveCompletion = receiveCompletion ?? { _ in }
            self.receiveValue = receiveValue
        }

        public func receive(subscription: Subscription) {
            if _upstreamSubscription == nil {
                _upstreamSubscription = subscription
                subscription.request(.unlimited)
            } else {
                subscription.cancel()
            }
        }

        public func receive(_ value: Input) -> Subscribers.Demand {
            receiveValue(value)
            return .none
        }

        public func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)
        }

        public func cancel() {
            _upstreamSubscription?.cancel()
            _upstreamSubscription = nil
        }
    }
}

extension Publisher {

    /// Attaches a subscriber with closure-based behavior.
    ///
    /// This method creates the subscriber and immediately requests an unlimited number
    /// of values, prior to returning the subscriber.
    /// - parameter receiveValue: The closure to execute on receipt of a value. If `nil`,
    ///   the sink uses an empty closure.
    /// - parameter receiveComplete: The closure to execute on completion. If `nil`,
    ///   the sink uses an empty closure.
    /// - Returns: A subscriber that performs the provided closures upon receiving values
    ///   or completion.
    public func sink(
        receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
        receiveValue: @escaping ((Output) -> Void)
    ) -> Subscribers.Sink<Output, Failure> {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: receiveCompletion,
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return subscriber
    }
}
