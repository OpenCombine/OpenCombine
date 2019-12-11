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
            subscriber.receive(subscription: inner)
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
        private var pendingDemand = Subscribers.Demand.none
        private let lock = UnfairLock.allocate()
        private var events: Publishers.HandleEvents<Upstream>?
        private let downstream: Downstream

        init(_ events: Publishers.HandleEvents<Upstream>, downstream: Downstream) {
            self.events = events
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            events?.receiveSubscription?(subscription)
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            lock.unlock()
            if pendingDemand > 0 {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            events?.receiveOutput?(input)
            let newDemand = downstream.receive(input)
            if newDemand > 0 {
                events?.receiveRequest?(newDemand)
            }
            return newDemand
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            events?.receiveCompletion?(completion)
            lock.lock()
            events = nil
            status = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            events?.receiveRequest?(demand)
            lock.lock()
            if case let .subscribed(subscription) = status {
                lock.unlock()
                subscription.request(demand)
                return
            }
            pendingDemand += demand
            lock.unlock()
        }

        func cancel() {
            events?.receiveCancel?()
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            events = nil
            status = .terminal
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "HandleEvents" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
