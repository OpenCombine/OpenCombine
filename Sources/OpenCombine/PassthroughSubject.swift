//
//  PassthroughSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A subject that passes along values and completion.
///
/// Use a `PassthroughSubject` in unit tests when you want a publisher than can publish
/// specific values on-demand during tests.
public final class PassthroughSubject<Output, Failure: Error>: Subject {

    private let lock = UnfairLock.allocate() // 0x10

    private var active = true // 0x18

    private var completion: Subscribers.Completion<Failure>?

    private var downstreams = SubscriberList() // [PassthroughSubject.Conduit]

    private var upstreamSubscriptions = [Subscription]()

    private var hasAnyDownstreamDemand = false

    public init() {}

    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
		lock.deallocate()
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        lock.lock()
        if active {
            let subscription = Conduit(self, subscriber)
            lock.unlock()
            subscriber.receive(subscription: subscription)
        } else {
            let completion = self.completion!
            lock.unlock()
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
        }
    }

    public func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        let hasAnyDownstreamDemand = self.hasAnyDownstreamDemand
        lock.unlock()
        if hasAnyDownstreamDemand {
            subscription.request(.unlimited)
        }
    }

    public func send(_ input: Output) {
        lock.lock()
        guard active, hasAnyDownstreamDemand else {
            lock.unlock()
            return
        }
        let downstreams = self.downstreams
        downstreams.retainAll()
        lock.unlock()
        for downstream in downstreams {
            unsafeDowncast(downstream.takeUnretainedValue(), to: Conduit.self)
                .offer(input)
            downstream.release()
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        active = false
        self.completion = completion
        let downstreams = self.downstreams
        self.downstreams.clear()
        lock.unlock()
        for downstream in downstreams {
            unsafeDowncast(downstream.takeUnretainedValue(), to: Conduit.self)
                .finish(completion: completion)
            downstream.release() // Release each conduit one last time
        }
    }

    private func acknowledgeDownstreamDemand() {
        lock.lock()
        if hasAnyDownstreamDemand {
            lock.unlock()
            return
        }
        hasAnyDownstreamDemand = true
        lock.unlock()
        for subscription in upstreamSubscriptions {
            subscription.request(.unlimited)
        }
    }

    private func disassociate(_ ticket: Ticket) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        downstreams.remove(for: ticket)
        lock.unlock()
    }
}

extension PassthroughSubject {

    fileprivate final class Conduit: Subscription {

        // Unmanaged<PassthroughSubject>
        private let erasedParent: Unmanaged<AnyObject>

        // Unmanaged<_ReferencedBasedAnySubscriber>
        private let erasedDownstream: Unmanaged<AnyObject>

        private var identity: Ticket

        private var released = false

        private var demand = Subscribers.Demand.none

        private let lock = UnfairLock.allocate()

        private let downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate init<Downstream: Subscriber>(_ parent: PassthroughSubject,
                                                 _ downstream: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            erasedParent = .passRetained(parent)
            erasedDownstream = .passRetained(_ReferencedBasedAnySubscriber(downstream))
            identity = .min
            identity = parent.downstreams.insert(.passRetained(self))
        }

        fileprivate func offer(_ value: Output) {
            lock.lock()
            guard demand > 0, !released else {
                lock.unlock()
                return
            }
            demand -= 1
            let downstream = unsafeDowncast(
                erasedDownstream.retain().takeUnretainedValue(),
                to: _ReferencedBasedAnySubscriber<Output, Failure>.self
            )
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(value)
            erasedDownstream.release()
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            demand += newDemand
            lock.unlock()
        }

        fileprivate func finish(completion: Subscribers.Completion<Failure>) {
            release {
                downstreamLock.lock()
                unsafeDowncast(erasedDownstream.takeUnretainedValue(),
                               to: _ReferencedBasedAnySubscriber<Output, Failure>.self)
                    .receive(completion: completion)
                downstreamLock.unlock()
            }
        }

        @inline(__always)
        private func release(_ body: () -> Void) {
            lock.lock()
            if released {
                lock.unlock()
                return
            }
            released = true
            lock.unlock()
            unsafeDowncast(erasedParent.takeUnretainedValue(),
                           to: PassthroughSubject<Output, Failure>.self)
                .disassociate(identity)
            body()
            erasedParent.release()
            erasedDownstream.release()
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            if released {
                lock.unlock()
                return
            }
            self.demand += demand
            let parent = unsafeDowncast(erasedParent.retain().takeUnretainedValue(),
                                        to: PassthroughSubject<Output, Failure>.self)
            lock.unlock()
            parent.acknowledgeDownstreamDemand()
            erasedParent.release()
        }

        fileprivate func cancel() {
            release {}
        }

        deinit {
            if !released {
                // This deinit is only ever called if the instance is not in
                // the SubscriberList. But the `released` flag is set to true whenever
                // we remove the instance from the SubscriberList.
                assertionFailure("should never happen")
                erasedParent.release()
                erasedDownstream.release()
            }
            lock.deallocate()
            downstreamLock.deallocate()
        }
    }
}

extension PassthroughSubject.Conduit: CustomStringConvertible {
    fileprivate var description: String { return "PassthroughSubject" }
}

extension PassthroughSubject.Conduit: CustomReflectable {
    fileprivate var customMirror: Mirror {
        lock.lock()
        defer { lock.unlock() }

        // FIXME: Without this precondition, we may have a use-after-free.
        // This is a bug in Combine (FB7283444). When this is fixed in Combine,
        // we'll change our implementation.
        precondition(!released)

        let children: [Mirror.Child] = [
            ("parent", erasedParent.takeUnretainedValue()),
            ("downstream", erasedDownstream.takeUnretainedValue()),
            ("demand", demand),
            ("subject", erasedParent.takeUnretainedValue())
        ]
        return Mirror(self, children: children)
    }
}

extension PassthroughSubject.Conduit: CustomPlaygroundDisplayConvertible {
    fileprivate var playgroundDescription: Any { return description }
}
