//
//  Publishers.SubscribeOn.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.12.2019.
//

extension Publisher {

    /// Specifies the scheduler on which to perform subscribe, cancel, and request
    /// operations.
    ///
    /// In contrast with `receive(on:options:)`, which affects downstream messages,
    /// `subscribe(on:)` changes the execution context of upstream messages.
    /// In the following example, requests to `jsonPublisher` are performed on
    /// `backgroundQueue`, but elements received from it are performed on `RunLoop.main`.
    ///
    ///     let ioPerformingPublisher == // Some publisher.
    ///     let uiUpdatingSubscriber == // Some subscriber that updates the UI.
    ///
    ///     ioPerformingPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receiveOn(on: RunLoop.main)
    ///         .subscribe(uiUpdatingSubscriber)
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler on which to receive upstream messages.
    ///   - options: Options that customize the delivery of elements.
    /// - Returns: A publisher which performs upstream operations on the specified
    ///   scheduler.
    public func subscribe<Context: Scheduler>(
        on scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.SubscribeOn<Self, Context> {
        return .init(upstream: self, scheduler: scheduler, options: options)
    }
}

extension Publishers {

    /// A publisher that receives elements from an upstream publisher on a specific
    /// scheduler.
    public struct SubscribeOn<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The scheduler the publisher should use to receive elements.
        public let scheduler: Context

        /// Scheduler options that customize the delivery of elements.
        public let options: Context.SchedulerOptions?

        public init(upstream: Upstream,
                    scheduler: Context,
                    options: Context.SchedulerOptions?) {
            self.upstream = upstream
            self.scheduler = scheduler
            self.options = options
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            scheduler.schedule(options: options) {
                self.upstream.subscribe(Inner(self, downstream: subscriber))
            }
        }
    }
}

extension Publishers.SubscribeOn {
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

        typealias SubscribeOn = Publishers.SubscribeOn<Upstream, Context>

       private enum State {
            case ready(SubscribeOn, Downstream)
            case subscribed(SubscribeOn, Downstream, Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private var state: State
        private let upstreamLock = UnfairLock.allocate()

        init(_ subscribeOn: SubscribeOn, downstream: Downstream) {
            state = .ready(subscribeOn, downstream)
        }

        deinit {
            lock.deallocate()
            upstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(subscribeOn, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscribeOn, downstream, subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(_, downstream, _) = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case let .subscribed(_, downstream, _) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscribeOn, _, subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscribeOn.scheduler.schedule(options: subscribeOn.options) { [weak self] in
                self?.scheduledRequest(demand, subscription: subscription)
            }
        }

        private func scheduledRequest(_ demand: Subscribers.Demand,
                                      subscription: Subscription) {
            upstreamLock.lock()
            subscription.request(demand)
            upstreamLock.unlock()
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(subscribeOn, _, subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subscribeOn.scheduler.schedule(options: subscribeOn.options) { [weak self] in
                self?.scheduledCancel(subscription)
            }
        }

        private func scheduledCancel(_ subscription: Subscription) {
            upstreamLock.lock()
            subscription.cancel()
            upstreamLock.unlock()
        }

        var description: String { return "SubscribeOn" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
