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
        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        public let upstream: Upstream

        public let createSubject: () -> SubjectType

        private lazy var _subject: SubjectType = self.createSubject()

        public init(upstream: Upstream, createSubject: @escaping () -> SubjectType) {
            self.upstream = upstream
            self.createSubject = createSubject
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where SubjectType.Failure == Downstream.Failure,
                  SubjectType.Output == Downstream.Input
        {
            _subject.subscribe(Inner(downstream: subscriber))
        }

        public func connect() -> Cancellable {
            return upstream.subscribe(_subject)
        }
    }
}

extension Publishers.Multicast {

    private final class Inner<Downstream: Subscriber>
        : OperatorSubscription<Downstream>,
          Subscriber,
          CustomStringConvertible,
          Subscription
        where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        var description: String { return "Multicast" }

        func receive(subscription: Subscription) {
            upstreamSubscription = subscription
            downstream.receive(subscription: self)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            upstreamSubscription?.request(demand)
        }
    }
}
