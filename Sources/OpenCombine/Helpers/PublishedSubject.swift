//
//  PublishedSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 29.10.2020.
//

internal final class PublishedSubject<Output>: Subject {

    internal typealias Failure = Never

    private let lock = UnfairLock.allocate()

    private var downstreams = ConduitList<Output, Failure>.empty

    private var currentValue: Output

    private var upstreamSubscriptions: [Subscription] = []

    private var hasAnyDownstreamDemand = false

    private var changePublisher: ObservableObjectPublisher?

    internal var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentValue
        }
        set {
            send(newValue)
        }
    }

    internal var objectWillChange: ObservableObjectPublisher? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return changePublisher
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            changePublisher = newValue
        }
    }

    internal init(_ value: Output) {
        self.currentValue = value
    }

    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }

    internal func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        subscription.request(.unlimited)
    }

    internal func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Never
    {
        lock.lock()
        let conduit = Conduit(parent: self, downstream: subscriber)
        downstreams.insert(conduit)
        lock.unlock()
        subscriber.receive(subscription: conduit)
    }

    internal func send(_ input: Output) {
        lock.lock()
        let downstreams = self.downstreams
        let changePublisher = self.changePublisher
        lock.unlock()
        changePublisher?.send()
        downstreams.forEach { conduit in
            conduit.offer(input)
        }
        lock.lock()
        currentValue = input
        lock.unlock()
    }

    internal func send(completion: Subscribers.Completion<Never>) {
        fatalError("unreachable")
    }

    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        lock.lock()
        downstreams.remove(conduit)
        lock.unlock()
    }
}

extension PublishedSubject {

    private final class Conduit<Downstream: Subscriber>
        : ConduitBase<Output, Failure>,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Never
    {

        fileprivate var parent: PublishedSubject?

        fileprivate var downstream: Downstream?

        fileprivate var demand = Subscribers.Demand.none

        private var lock = UnfairLock.allocate()

        private var downstreamLock = UnfairRecursiveLock.allocate()

        private var deliveredCurrentValue = false

        fileprivate init(parent: PublishedSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                deliveredCurrentValue = false
                lock.unlock()
                return
            }
            demand -= 1
            deliveredCurrentValue = true
            lock.unlock()
            downstreamLock.lock()
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            demand += newDemand
            lock.unlock()
        }

        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            if deliveredCurrentValue {
                self.demand += demand
                lock.unlock()
                return
            }

            // Hasn't yet delivered the current value

            self.demand += demand
            deliveredCurrentValue = true
            if let currentValue = self.parent?.value {
                self.demand -= 1
                lock.unlock()
                downstreamLock.lock()
                let newDemand = downstream.receive(currentValue)
                downstreamLock.unlock()
                guard newDemand > 0 else { return }
                lock.lock()
                self.demand += newDemand
            }
            lock.unlock()
        }

        override func cancel() {
            lock.lock()
            if self.downstream == nil {
                lock.unlock()
                return
            }
            self.downstream = nil
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
        }

        var description: String { return "PublishedSubject" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("parent", parent as Any),
                ("downstream", downstream as Any),
                ("demand", demand),
                ("subject", parent as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
