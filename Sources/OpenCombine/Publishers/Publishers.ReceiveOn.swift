//
//  Publishers.ReceiveOn.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.12.2019.
//

extension Publisher {
    /// Specifies the scheduler on which to receive elements from the publisher.
    ///
    /// You use the `receive(on:options:)` operator to receive results on a specific
    /// scheduler, such as performing UI work on the main run loop.
    /// In contrast with `subscribe(on:options:)`, which affects upstream messages,
    /// `receive(on:options:)` changes the execution context of downstream messages.
    /// In the following example, requests to `jsonPublisher` are performed on
    /// `backgroundQueue`, but elements received from it are performed on `RunLoop.main`.
    ///
    ///     // Some publisher.
    ///     let jsonPublisher = MyJSONLoaderPublisher()
    ///
    ///     // Some subscriber that updates the UI.
    ///     let labelUpdater = MyLabelUpdateSubscriber()
    ///
    ///     jsonPublisher
    ///         .subscribe(on: backgroundQueue)
    ///         .receiveOn(on: RunLoop.main)
    ///         .subscribe(labelUpdater)
    ///
    /// - Parameters:
    ///   - scheduler: The scheduler the publisher is to use for element delivery.
    ///   - options: Scheduler options that customize the element delivery.
    /// - Returns: A publisher that delivers elements using the specified scheduler.
    public func receive<Context: Scheduler>(
        on scheduler: Context,
        options: Context.SchedulerOptions? = nil
    ) -> Publishers.ReceiveOn<Self, Context> {
        return .init(upstream: self, scheduler: scheduler, options: options)
    }
}

extension Publishers {

    /// A publisher that delivers elements to its downstream subscriber on a specific
    /// scheduler.
    public struct ReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The scheduler the publisher is to use for element delivery.
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
            upstream.subscribe(Inner(self, downstream: subscriber))
        }
    }
}

extension Publishers.ReceiveOn {
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

        typealias ReceiveOn = Publishers.ReceiveOn<Upstream, Context>

        private enum State {
            case ready(ReceiveOn, Downstream)
            case subscribed(ReceiveOn, Downstream, Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private var state: State
        private let downstreamLock = UnfairRecursiveLock.allocate()

        init(_ receiveOn: ReceiveOn, downstream: Downstream) {
            state = .ready(receiveOn, downstream)
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(receiveOn, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(receiveOn, downstream, subscription)
            lock.unlock()
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(receiveOn, downstream, _) = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            receiveOn.scheduler.schedule(options: receiveOn.options) { [weak self] in
                self?.scheduledReceive(input, downstream: downstream)
            }
            return .none
        }

        private func scheduledReceive(_ input: Upstream.Output, downstream: Downstream) {
            downstreamLock.lock()
            let newDemand = downstream.receive(input)
            downstreamLock.unlock()
            guard newDemand > 0 else {
                return
            }
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(newDemand)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case let .subscribed(receiveOn, downstream, _) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            receiveOn.scheduler.schedule(options: receiveOn.options) { [weak self] in
                self?.scheduledReceive(completion: completion, downstream: downstream)
            }
        }

        private func scheduledReceive(completion: Subscribers.Completion<Failure>,
                                      downstream: Downstream) {
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "ReceiveOn" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }
    }
}
