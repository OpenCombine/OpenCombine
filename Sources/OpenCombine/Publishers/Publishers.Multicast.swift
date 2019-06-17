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

        private let _upstream: Upstream

        private let _creator: () -> SubjectType

        private lazy var _subject: SubjectType = self._creator()

        internal init(upstream: Upstream, _ creator: @escaping () -> SubjectType) {
            _upstream = upstream
            _creator = creator
        }

        public func receive<S: Subscriber>(subscriber: S)
            where SubjectType.Failure == S.Failure, SubjectType.Output == S.Input
        {
            _subject.subscribe(subscriber)
        }

        public func connect() -> Cancellable {

            let subscriber = SubjectSubscriber(_subject)

            _upstream.subscribe(subscriber)

            return AnyCancellable {
                subscriber.parent = nil
            }
        }
    }
}

extension Publisher {

    public func multicast<S: Subject>(
        _ createSubject: @escaping () -> S
    ) -> Publishers.Multicast<Self, S> where Failure == S.Failure, Output == S.Output {
        return Publishers.Multicast(upstream: self, createSubject)
    }

    public func multicast<S: Subject>(subject: S) -> Publishers.Multicast<Self, S>
        where Failure == S.Failure, Output == S.Output
    {
        return multicast { subject }
    }
}

