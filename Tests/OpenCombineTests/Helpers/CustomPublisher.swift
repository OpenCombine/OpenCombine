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
@available(macOS 10.15, iOS 13.0, *)
typealias CustomPublisher = CustomPublisherBase<Int, TestingError>

@available(macOS 10.15, iOS 13.0, *)
final class CustomPublisherBase<Output: Equatable, Failure: Error>: Publisher {

    private(set) var subscriber: AnySubscriber<Output, Failure>?
    private(set) var erasedSubscriber: Any?
    private let subscription: Subscription?

    init(subscription: Subscription?) {
        self.subscription = subscription
    }

    func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
    {
        self.subscriber = AnySubscriber(subscriber)
        erasedSubscriber = subscriber
        subscription.map(subscriber.receive(subscription:))
    }

    func send(_ value: Output) -> Subscribers.Demand {
        return subscriber?.receive(value) ?? .none
    }

    func send(completion: Subscribers.Completion<Failure>) {
        subscriber!.receive(completion: completion)
    }
}
