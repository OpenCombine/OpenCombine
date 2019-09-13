//
//  Publishers.Zip.swift
//
//  Created by Eric Patey on 29.08.2019.
//

extension Publishers {

    /// A publisher created by applying the zip function to two upstream publishers.
    public struct Zip<UpstreamA, UpstreamB>: Publisher
        where UpstreamA: Publisher,
        UpstreamB: Publisher,
        UpstreamA.Failure == UpstreamB.Failure
    {

        /// The kind of values published by this publisher.
        public typealias Output = (UpstreamA.Output, UpstreamB.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = UpstreamA.Failure

        public let a: UpstreamA

        public let b: UpstreamB

        public init(_ a: UpstreamA, _ b: UpstreamB) {
            self.a = a
            self.b = b
        }

        /// This function is called to attach the specified `Subscriber` to this
        ///  `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream: Subscriber,
            UpstreamB.Failure == Downstream.Failure,
            Downstream.Input == (UpstreamA.Output, UpstreamB.Output)
        {
            _ = Inner<Downstream>(downstream: subscriber, a, b)
        }
    }

    /// A publisher created by applying the zip function to three upstream publishers.
    public struct Zip3<UpstreamA, UpstreamB, UpstreamC>: Publisher
        where UpstreamA: Publisher,
        UpstreamB: Publisher,
        UpstreamC: Publisher,
        UpstreamA.Failure == UpstreamB.Failure,
        UpstreamB.Failure == UpstreamC.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = (UpstreamA.Output, UpstreamB.Output, UpstreamC.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = UpstreamA.Failure

        public let a: UpstreamA

        public let b: UpstreamB

        public let c: UpstreamC

        public init(_ a: UpstreamA, _ b: UpstreamB, _ c: UpstreamC) {
            self.a = a
            self.b = b
            self.c = c
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream: Subscriber,
            UpstreamC.Failure == Downstream.Failure,
            // swiftlint:disable:next large_tuple
            Downstream.Input == (UpstreamA.Output, UpstreamB.Output, UpstreamC.Output)
        {
            _ = Inner<Downstream>(downstream: subscriber, a, b, c)
        }
    }

    /// A publisher created by applying the zip function to four upstream publishers.
    public struct Zip4<UpstreamA, UpstreamB, UpstreamC, UpstreamD>: Publisher
        where UpstreamA: Publisher,
        UpstreamB: Publisher,
        UpstreamC: Publisher,
        UpstreamD: Publisher,
        UpstreamA.Failure == UpstreamB.Failure,
        UpstreamB.Failure == UpstreamC.Failure,
        UpstreamC.Failure == UpstreamD.Failure
    {

        /// The kind of values published by this publisher.
        public typealias Output = (
            UpstreamA.Output,
            UpstreamB.Output,
            UpstreamC.Output,
            UpstreamD.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = UpstreamA.Failure

        public let a: UpstreamA

        public let b: UpstreamB

        public let c: UpstreamC

        public let d: UpstreamD

        public init(_ a: UpstreamA, _ b: UpstreamB, _ c: UpstreamC, _ d: UpstreamD) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
            where Downstream: Subscriber,
            UpstreamD.Failure == Downstream.Failure,
            // swiftlint:disable:next large_tuple
            Downstream.Input == (
            UpstreamA.Output,
            UpstreamB.Output,
            UpstreamC.Output,
            UpstreamD.Output)
        {
            _ = Inner<Downstream>(downstream: subscriber, a, b, c, d)
        }
    }
}

extension Publisher {

    /// Combine elements from another publisher and deliver pairs of elements as tuples.
    ///
    /// The returned publisher waits until both publishers have emitted an event, then
    /// delivers the oldest unconsumed event from each publisher together as a tuple to
    /// the subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    ///  emits event `c`, the zip publisher emits the tuple `(a, c)`. It won’t emit a
    ///   tuple with event `b` until `P2` emits another event.
    /// If either upstream publisher finishes successfuly or fails with an error, the
    /// zipped publisher does the same.
    ///
    /// - Parameter other: Another publisher.
    /// - Returns: A publisher that emits pairs of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other>(_ other: Other) -> Publishers.Zip<Self, Other>
        where Other: Publisher, Self.Failure == Other.Failure
    {
        return Publishers.Zip(self, other)
    }

    /// Combine elements from another publisher and deliver a transformed output.
    ///
    /// The returned publisher waits until both publishers have emitted an event, then
    ///  delivers the oldest unconsumed event from each publisher together as a tuple to
    ///  the subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits event `c`, the zip publisher emits the tuple `(a, c)`. It won’t emit a tuple
    /// with event `b` until `P2` emits another event.
    /// If either upstream publisher finishes successfuly or fails with an error, the
    /// zipped publisher does the same.
    ///
    /// - Parameter other: Another publisher.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///                and returns a new value to publish.
    /// - Returns: A publisher that emits pairs of elements from the upstream publishers
    ///            as tuples.
    public func zip<Other, Result>(
        _ other: Other,
        _ transform: @escaping (Self.Output, Other.Output) -> Result)
        -> Publishers.Map<Publishers.Zip<Self, Other>, Result>
        where Other: Publisher, Self.Failure == Other.Failure
    {
        return Publishers.Map(upstream: Publishers.Zip(self, other), transform: transform)
    }

    /// Combine elements from two other publishers and deliver groups of elements as
    /// tuples.
    ///
    /// The returned publisher waits until all three publishers have emitted an event,
    /// then delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the event `e`, the zip
    /// publisher emits the tuple `(a, c, e)`. It won’t emit a tuple with elements `b` or
    /// `d` until `P3` emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2>(_ publisher1: Other1, _ publisher2: Other2)
        -> Publishers.Zip3<Self, Other1, Other2>
        where Other1: Publisher,
        Other2: Publisher,
        Self.Failure == Other1.Failure,
        Other1.Failure == Other2.Failure
    {
        return Publishers.Zip3(self, publisher1, publisher2)
    }

    /// Combine elements from two other publishers and deliver a transformed output.
    ///
    /// The returned publisher waits until all three publishers have emitted an event,
    /// then delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the event `e`, the zip
    /// publisher emits the tuple `(a, c, e)`. It won’t emit a tuple with elements `b` or
    /// `d` until `P3` emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///                 and returns a new value to publish.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2, Result>(
        _ publisher1: Other1,
        _ publisher2: Other2,
        _ transform: @escaping (Self.Output, Other1.Output, Other2.Output) -> Result)
        -> Publishers.Map<Publishers.Zip3<Self, Other1, Other2>, Result>
        where Other1: Publisher,
        Other2: Publisher,
        Self.Failure == Other1.Failure,
        Other1.Failure == Other2.Failure
    {
        return Publishers.Map(upstream: Publishers.Zip3(self, publisher1, publisher2),
                              transform: transform)
    }

    /// Combine elements from three other publishers and deliver groups of elements as
    /// tuples.
    ///
    /// The returned publisher waits until all four publishers have emitted an event, then
    /// delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the elements `e` and `f`, and
    /// publisher `P4` emits the event `g`, the zip publisher emits the tuple
    /// `(a, c, e, g)`. It won’t emit a tuple with elements `b`, `d`, or `f` until `P4`
    /// emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - publisher3: A fourth publisher.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2, Other3>(_ publisher1: Other1,
                                            _ publisher2: Other2,
                                            _ publisher3: Other3)
        -> Publishers.Zip4<Self, Other1, Other2, Other3>
        where Other1: Publisher,
        Other2: Publisher,
        Other3: Publisher,
        Self.Failure == Other1.Failure,
        Other1.Failure == Other2.Failure,
        Other2.Failure == Other3.Failure
    {
        return Publishers.Zip4(self, publisher1, publisher2, publisher3)
    }

    /// Combine elements from three other publishers and deliver a transformed output.
    ///
    /// The returned publisher waits until all four publishers have emitted an event, then
    /// delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the elements `e` and `f`, and
    /// publisher `P4` emits the event `g`, the zip publisher emits the tuple
    /// `(a, c, e, g)`. It won’t emit a tuple with elements `b`, `d`, or `f` until `P4`
    /// emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - publisher3: A fourth publisher.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///                 and returns a new value to publish.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2, Other3, Result>(
        _ publisher1: Other1,
        _ publisher2: Other2,
        _ publisher3: Other3,
        _ transform: @escaping (Self.Output, Other1.Output, Other2.Output, Other3.Output)
        -> Result)
        -> Publishers.Map<Publishers.Zip4<Self, Other1, Other2, Other3>, Result>
        where Other1: Publisher,
        Other2: Publisher,
        Other3: Publisher,
        Self.Failure == Other1.Failure,
        Other1.Failure == Other2.Failure,
        Other2.Failure == Other3.Failure
    {
        return Publishers.Map(upstream: Publishers.Zip4(self,
                                                        publisher1,
                                                        publisher2,
                                                        publisher3),
                              transform: transform)
    }
}

extension Publishers.Zip {
    private class Inner<Downstream: Subscriber>: InnerBase<Downstream>
        where Downstream.Failure == Failure,
        Downstream.Input == (UpstreamA.Output, UpstreamB.Output)
    {
        private lazy var aSubscriber = ChildSubscriber<UpstreamA, Downstream>(self, 0)
        private lazy var bSubscriber = ChildSubscriber<UpstreamB, Downstream>(self, 1)

        init(downstream: Downstream, _ a: UpstreamA, _ b: UpstreamB) {
            super.init(downstream: downstream)

            a.subscribe(aSubscriber)
            b.subscribe(bSubscriber)
        }

        override fileprivate func lockedUpstreamSubscriptions() -> [ChildSubscription] {
            return [aSubscriber, bSubscriber]
        }

        override fileprivate func lockedDequeueValue() -> Downstream.Input {
            return (aSubscriber.dequeueValue(), bSubscriber.dequeueValue())
        }
    }
}

extension Publishers.Zip3 {
    private class Inner<Downstream: Subscriber>: InnerBase<Downstream>
        where Downstream.Failure == Failure,
        Downstream.Input == (UpstreamA.Output, UpstreamB.Output, UpstreamC.Output)
    {
        private lazy var aSubscriber = ChildSubscriber<UpstreamA, Downstream>(self, 0)
        private lazy var bSubscriber = ChildSubscriber<UpstreamB, Downstream>(self, 1)
        private lazy var cSubscriber = ChildSubscriber<UpstreamC, Downstream>(self, 2)

        init(downstream: Downstream, _ a: UpstreamA, _ b: UpstreamB, _ c: UpstreamC) {
            super.init(downstream: downstream)

            a.subscribe(aSubscriber)
            b.subscribe(bSubscriber)
            c.subscribe(cSubscriber)
        }

        override fileprivate func lockedUpstreamSubscriptions() -> [ChildSubscription] {
            return [aSubscriber, bSubscriber, cSubscriber]
        }

        override fileprivate func lockedDequeueValue() -> Downstream.Input {
            return (aSubscriber.dequeueValue(),
                    bSubscriber.dequeueValue(),
                    cSubscriber.dequeueValue())
        }
    }
}

extension Publishers.Zip4 {
    private class Inner<Downstream: Subscriber>: InnerBase<Downstream>
        where Downstream.Failure == Failure,
        Downstream.Input == (
        UpstreamA.Output,
        UpstreamB.Output,
        UpstreamC.Output,
        UpstreamD.Output)
    {
        private lazy var aSubscriber = ChildSubscriber<UpstreamA, Downstream>(self, 0)
        private lazy var bSubscriber = ChildSubscriber<UpstreamB, Downstream>(self, 1)
        private lazy var cSubscriber = ChildSubscriber<UpstreamC, Downstream>(self, 2)
        private lazy var dSubscriber = ChildSubscriber<UpstreamD, Downstream>(self, 3)

        init(downstream: Downstream,
             _ a: UpstreamA,
             _ b: UpstreamB,
             _ c: UpstreamC,
             _ d: UpstreamD)
        {
            super.init(downstream: downstream)

            a.subscribe(aSubscriber)
            b.subscribe(bSubscriber)
            c.subscribe(cSubscriber)
            d.subscribe(dSubscriber)
        }

        override fileprivate func lockedUpstreamSubscriptions() -> [ChildSubscription] {
            return [aSubscriber, bSubscriber, cSubscriber, dSubscriber]
        }

        override fileprivate func lockedDequeueValue() -> Downstream.Input {
            return (aSubscriber.dequeueValue(),
                    bSubscriber.dequeueValue(),
                    cSubscriber.dequeueValue(),
                    dSubscriber.dequeueValue())
        }
    }
}

private class InnerBase<Downstream: Subscriber>: CustomStringConvertible {
    let description = "Zip"

    private final let lock = Lock(recursive: false)
    // Locking rules for this class.
    //  - All mutable state must only be accessed while `lock` is held.
    //  - In order to avoid any deadlock potential, it is absolutely forbidden to have
    //      any sort of call out from this class while the lock is held. This is why
    //      the draining of the work queue uses a relatively complex pattern.
    private final var downstream: Downstream?
    private final var downstreamDemand = Subscribers.Demand.none
    private final var queueIsBeingProcessed = false
    private final var queuedWork = ArraySlice<QueuedWork>()
    // The following two pieces of state are a hacky implementation of subtle Apple
    // concurrency behaviors. Specifically, when Zip is processing an upstream child value
    // and sending a resulting value downstream, multiple behaviors are changed.
    //  1. If a downstream demand request comes in during this period, the demand request
    //     for that specific triggering upstream child will be communiated via the result
    //     of `.receive(_ input:)` INSTEAD of a later `.request(_ demand:)` call.
    //     (AppleRef: 001)
    //  2. If an upstream `.finished` comes in during this time period, the "finished
    //     asssessment check" (AppleRef: 002) is skipped.
    // If an upstream value is being processed when a downstream demand request comes in,
    // the demand for that specfic upstream child will be communiated via the result
    // of `.receive(_ input:)` INSTEAD of a later `.request(_ demand:)` call.
    private final var processingValueForChild: ChildSubscription?
    private final var demandReceivedWhileProcessing: Subscribers.Demand?

    init(downstream: Downstream) {
        self.downstream = downstream
    }

    fileprivate func lockedUpstreamSubscriptions() -> [ChildSubscription] {
        fatalError("override me")
    }

    fileprivate func lockedDequeueValue() -> Downstream.Input {
        fatalError("override me")
    }

    fileprivate final func receivedSubscription(for child: ChildSubscription) {
        let sendSubscriptionDownstream: Bool = lock.do {
            child.state = .active
            return lockedUpstreamSubscriptions()
                .filter { $0.state == .waitingForSubscription }
                .isEmpty
        }

        if sendSubscriptionDownstream {
            self.sendSubscriptionDownstream()
        }
    }

    fileprivate final func receivedChildValue(child: ChildSubscription, _ lockedStoreValue: () -> Void)
        -> Subscribers.Demand
    {
        let shouldProcessQueue: Bool = lock.do {
            lockedStoreValue()
            if let dequeuedValue = lockedMaybeDequeueValue() {
                queuedWork.append(.receivedValueFromUpstream(value: dequeuedValue))
                if !queueIsBeingProcessed {
                    assert(processingValueForChild == nil)
                    processingValueForChild = child
                    queueIsBeingProcessed = true
                    return true
                }
            }
            return false
        }

        var demandOverride: Subscribers.Demand?
        if shouldProcessQueue {
            demandOverride = processQueue()
        }

        return demandOverride ?? .none
    }

    fileprivate final func receivedCompletion(
        _ completion: Subscribers.Completion<Downstream.Failure>,
        forChild child: ChildSubscription)
    {
        switch completion {
        case .failure:
            downstream?.receive(completion: completion)
            let subscriptionsToCancel: [Subscription] = lock.do {
                child.state = .failed
                return lockedUpstreamSubscriptions()
            }
            subscriptionsToCancel.forEach { $0.cancel() }
        case .finished:
            let shouldProcessQueue: Bool = lock.do {
                child.state = .finished
                queuedWork.append(.receivedFinishedFromUpstream)
                if !queueIsBeingProcessed {
                    queueIsBeingProcessed = true
                    return true
                }
                return false
            }

            if shouldProcessQueue {
                assert(processQueue() == nil)
            }
        }
    }

    private func lockedMaybeDequeueValue() -> Downstream.Input? {
        return lockedHasCompleteValueAvailable() ? lockedDequeueValue() : nil
    }

    private func sendSubscriptionDownstream() {
        downstream?.receive(subscription: self)
    }

    private func lockedHasCompleteValueAvailable() -> Bool {
        return lockedUpstreamSubscriptions().allSatisfy { $0.hasValue() }
    }

    private func lockedAreMoreValuesPossible() -> Bool {
        // More values are possible if all children are (active || have surplus)
        return lockedUpstreamSubscriptions()
            .allSatisfy { $0.state == .active || $0.hasValue() }
    }

    private enum QueueAction {
        case stopProcessing
        case noAction
        case sendFinishDownstream
        case sendValueDownstream(_ value: Downstream.Input)
        case sendRequestUpstream(_ demand: Subscribers.Demand)
    }

    private enum QueuedWork {
        case receivedValueFromUpstream(value: Downstream.Input)
        case receivedFinishedFromUpstream
        case receivedRequestFromDownstream(demand: Subscribers.Demand)
    }

    private func lockedActionToTake() -> QueueAction {
        guard let work = self.queuedWork.popFirst() else { return .stopProcessing }
        switch work {
        case .receivedValueFromUpstream(let value):
            // TODO: Fix the implementation of Demand. I think it currently is too
            // strict given that the documentation says:
            //      any operation that would result in a negative value is
            //      clamped to .max(0).
            //It doesn't say anything about fatalErrors
            if downstreamDemand != .none {
                downstreamDemand -= 1
            }
            return .sendValueDownstream(value)
        case .receivedFinishedFromUpstream:
            return (processingValueForChild != nil || lockedAreMoreValuesPossible()) ? .noAction : .sendFinishDownstream
        case .receivedRequestFromDownstream(let demand):
            return .sendRequestUpstream(demand)
        }
    }

    private func processQueue() -> Subscribers.Demand? {
        assert(queueIsBeingProcessed)

        // We loop processing the queue in case somebody put stuff on the queue while we
        // were sending values with the lock unlocked.
        while true {
            var receiveValueDemandOverride: Subscribers.Demand?
            let action: QueueAction = lock.do {
                let work = lockedActionToTake()
                if case .stopProcessing = work {
                    queueIsBeingProcessed = false
                    processingValueForChild = nil
                    receiveValueDemandOverride = demandReceivedWhileProcessing
                    demandReceivedWhileProcessing = nil
                }
                return work
            }

            guard let downstream = downstream else { return nil }

            switch action {
            case .stopProcessing:
                return receiveValueDemandOverride
            case .noAction:
                break
            case .sendFinishDownstream:
                downstream.receive(completion: .finished)
                let activeChildren = lock.do {
                    lockedUpstreamSubscriptions().filter { $0.state == .active }
                }
                activeChildren.forEach { $0.cancel() }
                return receiveValueDemandOverride
            case .sendValueDownstream(let value):
                let newDemand =  downstream.receive(value)
                if newDemand != .none {
                    lock.do { downstreamDemand += newDemand }
                }
            case .sendRequestUpstream(let demand):
                lock.do { lockedUpstreamSubscriptions()
                    .filter { $0.childIndex
                        != processingValueForChild?.childIndex } }
                    .forEach { $0.request(demand) }
            }
        }
    }
}

extension InnerBase: Subscription {
    fileprivate final func request(_ demand: Subscribers.Demand) {
        if demand == .none {
            return
        }
        let shouldProcessQueue: Bool = lock.do {
            downstreamDemand += demand  // TODO: Move this to the action processing?
            queuedWork.append(.receivedRequestFromDownstream(demand: demand))
            if queueIsBeingProcessed {
                demandReceivedWhileProcessing = demand
            } else {
                queueIsBeingProcessed = true
                return true
            }
            return false
        }

        if shouldProcessQueue {
            assert(processQueue() == nil)
        }
    }

    fileprivate final func cancel() {
        lock.do(lockedUpstreamSubscriptions).forEach { $0.cancel() }
    }
}

private enum ChildState {
    case waitingForSubscription
    case active
    case finished
    case failed
    case canceled
}

// Note that it's critical that this protocol not have any associated types - specifically
// note that it does not refer to `Upstream`.
// This allows `InnerBase` to do most of the heavy lifting without regard to the
// upstream publisher's value type.
private protocol ChildSubscription: AnyObject, Subscription {
    var state: ChildState { get set }
    var childIndex: Int { get }

    func hasValue() -> Bool
}

fileprivate final class ChildSubscriber<Upstream: Publisher, Downstream: Subscriber>
    where Upstream.Failure == Downstream.Failure
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure

    fileprivate final var state: ChildState = .waitingForSubscription
    fileprivate final var upstreamSubscription: Subscription?
    private var values = [Upstream.Output]()
    private unowned let parent: InnerBase<Downstream>
    fileprivate let childIndex: Int

    init(_ parent: InnerBase<Downstream>, _ childIndex: Int) {
        self.parent = parent
        self.childIndex = childIndex
    }

    fileprivate final func appendValue(_ value: Upstream.Output) {
        values.append(value)
    }

    fileprivate final func dequeueValue() -> Upstream.Output {
        return values.remove(at: 0)
    }
}

extension ChildSubscriber: ChildSubscription {
    fileprivate final func hasValue() -> Bool {
        return !values.isEmpty
    }
}

extension ChildSubscriber: Subscription {
    fileprivate final func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }
}

extension ChildSubscriber: Cancellable {
    fileprivate final func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
    }
}

extension ChildSubscriber: Subscriber {
    fileprivate final func receive(subscription: Subscription) {
        if upstreamSubscription == nil {
            upstreamSubscription = subscription
            parent.receivedSubscription(for: self)
        } else {
            assertionFailure()
            subscription.cancel()
        }
    }

    fileprivate final func receive(_ input: Input) -> Subscribers.Demand {
        return parent.receivedChildValue(child: self) { values.append(input) }
    }

    fileprivate final func receive(completion: Subscribers.Completion<Failure>) {
        parent.receivedCompletion(completion, forChild: self)
    }
}
