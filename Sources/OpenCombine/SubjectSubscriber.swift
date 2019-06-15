//
//  SubjectSubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

internal final class SubjectSubscriber<S: Subject>: Subscriber, CustomStringConvertible {

    var parent: S?
    var upstreamSubscription: Subscription?

    init(_ parent: S) {
        self.parent = parent
    }

    func receive(subscription: Subscription) {
        upstreamSubscription = subscription
        subscription.request(.unlimited)
    }

    func receive(_ input: S.Output) -> Subscribers.Demand {
        parent?.send(input)
        return .none
    }

    func receive(completion: Subscribers.Completion<S.Failure>) {
        parent?.send(completion: completion)
    }

    var description: String { "Subject" }
}

