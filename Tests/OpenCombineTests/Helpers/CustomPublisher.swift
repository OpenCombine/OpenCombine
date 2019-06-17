//
//  CustomPublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
final class CustomPublisher: Publisher {

    typealias Output = Int
    typealias Failure = TestingError

    private var subscriber: AnySubscriber<Int, TestingError>?
    private let subscription: Subscription?

    init(subscription: Subscription?) {
        self.subscription = subscription
    }

    func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        self.subscriber = AnySubscriber(subscriber)
        subscription.map(subscriber.receive(subscription:))
    }

    func send(_ value: Int) -> Subscribers.Demand {
        return subscriber!.receive(value)
    }

    func send(completion: Subscribers.Completion<TestingError>) {
        subscriber!.receive(completion: completion)
    }
}
