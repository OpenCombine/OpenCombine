//
//  SubjectSubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 16/09/2019.
//

internal final class SubjectSubscriber<Downstream: Subject>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      Subscription
{
    internal var downstreamSubject: Downstream?
    internal var upstreamSubscription: Subscription?

    internal init(_ parent: Downstream) {
        self.downstreamSubject = parent
    }

    internal func receive(subscription: Subscription) {
        guard upstreamSubscription == nil else { return }
        upstreamSubscription = subscription
        downstreamSubject?.send(subscription: self)
    }

    internal func receive(_ input: Downstream.Output) -> Subscribers.Demand {
        downstreamSubject?.send(input)
        return .none
    }

    internal func receive(completion: Subscribers.Completion<Downstream.Failure>) {
        downstreamSubject?.send(completion: completion)
        downstreamSubject = nil
    }

    internal var description: String { return "Subject" }

    internal var customMirror: Mirror {
        let children: [(label: String?, value: Any)] = [
            (label: "downstreamSubject", value: downstreamSubject as Any),
            (label: "upstreamSubscription", value: upstreamSubscription as Any)
        ]
        return Mirror(self, children: children)
    }

    internal func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }

    internal func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
        downstreamSubject = nil
    }
}

