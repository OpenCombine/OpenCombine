//
//  Publishers.Multicast.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

extension Publisher {

    public func multicast<SubjectType: Subject>(
        _ createSubject: @escaping () -> SubjectType
    ) -> Publishers.Multicast<Self, SubjectType>
        where Failure == SubjectType.Failure, Output == SubjectType.Output
    {
        return Publishers.Multicast(upstream: self, createSubject: createSubject)
    }

    public func multicast<SubjectType: Subject>(
        subject: SubjectType
    ) -> Publishers.Multicast<Self, SubjectType>
        where Failure == SubjectType.Failure, Output == SubjectType.Output
    {
        return multicast { subject }
    }
}

extension Publishers {

    public final class Multicast<Upstream: Publisher, SubjectType: Subject>
        : ConnectablePublisher
        where Upstream.Failure == SubjectType.Failure,
              Upstream.Output == SubjectType.Output
    {
        // NOTE: This class has been audited for thread safety

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let createSubject: () -> SubjectType

        private let lock = unfairLock()

        private var subject: SubjectType?

        private var lazySubject: SubjectType {
            lock.lock()
            if let subject = subject {
                lock.unlock()
                return subject
            }

            let subject = createSubject()
            self.subject = subject
            lock.unlock()
            return subject
        }

        public init(upstream: Upstream, createSubject: @escaping () -> SubjectType) {
            self.upstream = upstream
            self.createSubject = createSubject
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where SubjectType.Failure == Downstream.Failure,
                  SubjectType.Output == Downstream.Input
        {
            lazySubject.subscribe(Inner(parent: self, downstream: subscriber))
        }

        public func connect() -> Cancellable {
            return upstream.subscribe(lazySubject)
        }
    }
}

extension Publishers.Multicast {

    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        // NOTE: This class has been audited for thread safety

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private enum State {
            case ready(upstream: Upstream, downstream: Downstream)
            case subscribed(upstream: Upstream,
                            downstream: Downstream,
                            subjectSubscription: Subscription)
            case terminal
        }

        private let lock = unfairLock()

        private var state: State

        fileprivate init(parent: Publishers.Multicast<Upstream, SubjectType>,
                         downstream: Downstream) {
            state = .ready(upstream: parent.upstream, downstream: downstream)
        }

        fileprivate var description: String { return "Multicast" }

        fileprivate var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        fileprivate var playgroundDescription: Any { return description }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(upstream, downstream) = state else {
                lock.unlock()
                return
            }
            state = .subscribed(upstream: upstream,
                                downstream: downstream,
                                subjectSubscription: subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(_, downstream, subjectSubscription) = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            let newDemand = downstream.receive(input)
            if newDemand > 0 {
                subjectSubscription.request(newDemand)
            }
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
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
            guard case let .subscribed(_, _, subjectSubscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subjectSubscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subjectSubscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subjectSubscription.cancel()
        }
    }
}
