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
        // NOTE: this class has been audited for thread safety.
        // Combine doesn't use any locking here.

        /// The closure to execute on receipt of a value.
        public let receiveValue: (Input) -> Void

        /// The closure to execute on completion.
        public let receiveCompletion: (Subscribers.Completion<Failure>) -> Void

        private var status = SubscriptionStatus.awaitingSubscription

        public var description: String { return "Sink" }

        public var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        public var playgroundDescription: Any { return description }

        /// Initializes a sink with the provided closures.
        ///
        /// - Parameters:
        ///   - receiveCompletion: The closure to execute on completion.
        ///   - receiveValue: The closure to execute on receipt of a value.
        public init(
            receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
            receiveValue: @escaping ((Input) -> Void)
        ) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
        }

        public func receive(subscription: Subscription) {
            switch status {
            case .subscribed, .terminal:
                subscription.cancel()
            case .awaitingSubscription:
                status = .subscribed(subscription)
                subscription.request(.unlimited)
            }
        }

        public func receive(_ value: Input) -> Subscribers.Demand {
            receiveValue(value)
            return .none
        }

        public func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)
            status = .terminal
        }

        public func cancel() {
            guard case let .subscribed(subscription) = status else {
                return
            }
            subscription.cancel()
            status = .terminal
        }
    }
}

extension Publisher {

    /// Attaches a subscriber with closure-based behavior.
    ///
    /// This method creates the subscriber and immediately requests an unlimited number
    /// of values, prior to returning the subscriber.
    ///
    /// - parameter receiveComplete: The closure to execute on completion.
    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance; used when you end assignment of
    ///   the received value. Deallocation of the result will tear down
    ///   the subscription stream.
    public func sink(
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
        receiveValue: @escaping ((Output) -> Void)
    ) -> AnyCancellable {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: receiveCompletion,
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}

extension Publisher where Failure == Never {

    /// Attaches a subscriber with closure-based behavior.
    ///
    /// This method creates the subscriber and immediately requests an unlimited number
    /// of values, prior to returning the subscriber.
    ///
    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance; used when you end assignment of
    ///   the received value. Deallocation of the result will tear down
    ///   the subscription stream.
    public func sink(
        receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: { _ in },
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
