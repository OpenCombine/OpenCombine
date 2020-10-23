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
      CustomPlaygroundDisplayConvertible,
      Subscription
{
    private let lock = UnfairLock.allocate()
    private weak var downstreamSubject: Downstream?
    private var upstreamSubscription: Subscription?

    private var isCancelled: Bool { return downstreamSubject == nil }

    internal init(_ parent: Downstream) {
        self.downstreamSubject = parent
    }

    deinit {
        lock.deallocate()
    }

    internal func receive(subscription: Subscription) {
        lock.lock()
        guard upstreamSubscription == nil, let subject = downstreamSubject else {
            lock.unlock()
            return
        }
        upstreamSubscription = subscription
        lock.unlock()
        subject.send(subscription: self)
    }

    internal func receive(_ input: Downstream.Output) -> Subscribers.Demand {
        lock.lock()
        guard let subject = downstreamSubject, upstreamSubscription != nil else {
            lock.unlock()
            return .none
        }
        lock.unlock()
        subject.send(input)
        return .none
    }

    internal func receive(completion: Subscribers.Completion<Downstream.Failure>) {
        lock.lock()
        guard let subject = downstreamSubject, upstreamSubscription != nil else {
            lock.unlock()
            return
        }
        lock.unlock()
        subject.send(completion: completion)
        downstreamSubject = nil
    }

    internal var description: String { return "Subject" }

    internal var playgroundDescription: Any { return description }

    internal var customMirror: Mirror {
        let children: [Mirror.Child] = [
            ("downstreamSubject", downstreamSubject as Any),
            ("upstreamSubscription", upstreamSubscription as Any),
            ("subject", downstreamSubject as Any)
        ]
        return Mirror(self, children: children)
    }

    internal func request(_ demand: Subscribers.Demand) {
        lock.lock()
        guard let subscription = upstreamSubscription else {
            lock.unlock()
            return
        }
        lock.unlock()
        subscription.request(demand)
    }

    internal func cancel() {
        lock.lock()
        guard !isCancelled, let subscription = upstreamSubscription else {
            lock.unlock()
            return
        }
        upstreamSubscription = nil
        downstreamSubject = nil
        lock.unlock()
        subscription.cancel()
    }
}
