//
//  PublishedSubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 29.10.2020.
//

internal struct PublishedSubscriber<Value>: Subscriber {

    internal typealias Input = Value

    internal typealias Failure = Never

    internal let combineIdentifier = CombineIdentifier()

    private weak var subject: PublishedSubject<Value>?

    internal init(_ subject: PublishedSubject<Value>) {
        self.subject = subject
    }

    internal func receive(subscription: Subscription) {
        subject?.send(subscription: subscription)
    }

    internal func receive(_ input: Value) -> Subscribers.Demand {
        subject?.send(input)
        return .none
    }

    internal func receive(completion: Subscribers.Completion<Never>) {}
}
