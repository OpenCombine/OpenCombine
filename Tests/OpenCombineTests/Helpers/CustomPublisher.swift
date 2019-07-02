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

/// `CustomPublisher` sends the `subscription` object it has been initialized with
/// to whoever subscribed to this publisher.
///
/// This is useful in conjunction with the `CustomSubscription` class, which allows you
/// to track the demand requested by the subscribers of this publisher.
///
/// Example:
///
///     let subscription = CustomSubscription()
///     let publisher = CustomPublisher(subscription: subscription)
///
///     let subscriber = AnySubscriber(receiveSubscription: {
///         $0.request(42)
///         $0.cancel()
///     })
///
///     publisher.subscribe(subscriber)
///
///     assert(subscription.history == [.requested(.max(42)), .cancelled])
@available(macOS 10.15, *)
typealias CustomPublisher = CustomPublisherBase<Int>

@available(macOS 10.15, *)
final class CustomPublisherBase<Value: Equatable>: Publisher {

    typealias Output = Value
    typealias Failure = TestingError

    private var subscriber: AnySubscriber<Value, TestingError>?
    private let subscription: Subscription?

    init(subscription: Subscription?) {
        self.subscription = subscription
    }

    func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        self.subscriber = AnySubscriber(subscriber)
        subscription.map(subscriber.receive(subscription:))
    }

    func send(_ value: Value) -> Subscribers.Demand {
        return subscriber!.receive(value)
    }

    func send(completion: Subscribers.Completion<TestingError>) {
        subscriber!.receive(completion: completion)
    }
}
