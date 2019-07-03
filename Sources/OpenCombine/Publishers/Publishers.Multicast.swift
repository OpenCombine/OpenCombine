//
//  Publishers.Multicast.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

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

        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where SubjectType.Failure == SubscriberType.Failure,
                  SubjectType.Output == SubscriberType.Input
        {
            _subject.subscribe(subscriber)
        }

        public func connect() -> Cancellable {

            let subscriber = SubjectSubscriber(_subject)

            upstream.subscribe(subscriber)

            return AnyCancellable {
                subscriber.parent = nil
            }
        }
    }
}

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
