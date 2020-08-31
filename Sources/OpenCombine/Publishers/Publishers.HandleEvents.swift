//
//  Publishers.HandleEvents.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

extension Publisher {

    /// Performs the specified closures when publisher events occur.
    ///
    /// - Parameters:
    ///   - receiveSubscription: A closure that executes when the publisher receives
    ///     the subscription from the upstream publisher. Defaults to `nil`.
    ///   - receiveOutput: A closure that executes when the publisher receives a value
    ///     from the upstream publisher. Defaults to `nil`.
    ///   - receiveCompletion: A closure that executes when the publisher receives
    ///     the completion from the upstream publisher. Defaults to `nil`.
    ///   - receiveCancel: A closure that executes when the downstream receiver cancels
    ///     publishing. Defaults to `nil`.
    ///   - receiveRequest: A closure that executes when the publisher receives a request
    ///     for more elements. Defaults to `nil`.
    /// - Returns: A publisher that performs the specified closures when publisher events
    ///   occur.
    public func handleEvents(
        receiveSubscription: ((Subscription) -> Void)? = nil,
        receiveOutput: ((Output) -> Void)? = nil,
        receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
        receiveCancel: (() -> Void)? = nil,
        receiveRequest: ((Subscribers.Demand) -> Void)? = nil
    ) -> Publishers.HandleEvents<Self> {
        return .init(upstream: self,
                     receiveSubscription: receiveSubscription,
                     receiveOutput: receiveOutput,
                     receiveCompletion: receiveCompletion,
                     receiveCancel: receiveCancel,
                     receiveRequest: receiveRequest)
    }
}

extension Publishers {

    /// A publisher that performs the specified closures when publisher events occur.
    public struct HandleEvents<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that executes when the publisher receives the subscription from
        /// the upstream publisher.
        public var receiveSubscription: ((Subscription) -> Void)?

        ///  A closure that executes when the publisher receives a value from the upstream
        ///  publisher.
        public var receiveOutput: ((Upstream.Output) -> Void)?

        /// A closure that executes when the publisher receives the completion from
        /// the upstream publisher.
        public var receiveCompletion:
            ((Subscribers.Completion<Upstream.Failure>) -> Void)?

        ///  A closure that executes when the downstream receiver cancels publishing.
        public var receiveCancel: (() -> Void)?

        /// A closure that executes when the publisher receives a request for more
        /// elements.
        public var receiveRequest: ((Subscribers.Demand) -> Void)?

        public init(
            upstream: Upstream,
            receiveSubscription: ((Subscription) -> Void)? = nil,
            receiveOutput: ((Output) -> Void)? = nil,
            receiveCompletion: ((Subscribers.Completion<Failure>) -> Void)? = nil,
            receiveCancel: (() -> Void)? = nil,
            receiveRequest: ((Subscribers.Demand) -> Void)?
        ) {
            self.upstream = upstream
            self.receiveSubscription = receiveSubscription
            self.receiveOutput = receiveOutput
            self.receiveCompletion = receiveCompletion
            self.receiveCancel = receiveCancel
            self.receiveRequest = receiveRequest
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            let inner = Inner(self, downstream: subscriber)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.HandleEvents {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private var status = SubscriptionStatus.awaitingSubscription
        private let lock = UnfairLock.allocate()
        public var receiveSubscription: ((Subscription) -> Void)?
        public var receiveOutput: ((Upstream.Output) -> Void)?
        public var receiveCompletion:
            ((Subscribers.Completion<Upstream.Failure>) -> Void)?
        public var receiveCancel: (() -> Void)?
        public var receiveRequest: ((Subscribers.Demand) -> Void)?
        private let downstream: Downstream

        init(_ events: Publishers.HandleEvents<Upstream>, downstream: Downstream) {
            self.receiveSubscription = events.receiveSubscription
            self.receiveOutput = events.receiveOutput
            self.receiveCompletion = events.receiveCompletion
            self.receiveCancel = events.receiveCancel
            self.receiveRequest = events.receiveRequest
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            if let receiveSubscription = self.receiveSubscription {
                lock.unlock()
                receiveSubscription(subscription)
                lock.lock()
            }
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            if let receiveOutput = self.receiveOutput {
                lock.unlock()
                receiveOutput(input)
            } else {
                lock.unlock()
            }
            let newDemand = downstream.receive(input)
            if newDemand == .none {
                return newDemand
            }
            lock.lock()
            if let receiveRequest = self.receiveRequest {
                lock.unlock()
                receiveRequest(newDemand)
            } else {
                lock.unlock()
            }
            return newDemand
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            if let receiveCompletion = self.receiveCompletion {
                lock.unlock()
                receiveCompletion(completion)
                lock.lock()
            }
            lockedTerminate()
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            if let receiveRequest = self.receiveRequest {
                lock.unlock()
                receiveRequest(demand)
                lock.lock()
            }
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            if let receiveCancel = self.receiveCancel {
                lock.unlock()
                receiveCancel()
                lock.lock()
            }
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lockedTerminate()
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "HandleEvents" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }

        private func lockedTerminate() {
            receiveSubscription = nil
            receiveOutput       = nil
            receiveCompletion   = nil
            receiveCancel       = nil
            receiveRequest      = nil
            status = .terminal
        }
    }
}
