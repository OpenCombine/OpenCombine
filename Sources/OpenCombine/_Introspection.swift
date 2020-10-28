//
//  _Introspection.swift
//  
//
//  Created by Sergej Jaskiewicz on 27.09.2020.
//

public protocol _Introspection: AnyObject {

     func willReceive<Upstream: Publisher, Downstream: Subscriber>(
         publisher: Upstream,
         subscriber: Downstream
     ) where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input

     func didReceive<Upstream: Publisher, Downstream: Subscriber>(
         publisher: Upstream,
         subscriber: Downstream
     ) where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input

     func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                              subscription: Subscription)

     func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                             subscription: Subscription)

     func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                              input: Downstream.Input)

     func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                             input: Downstream.Input,
                                             resultingDemand: Subscribers.Demand)

     func willReceive<Downstream: Subscriber>(
         subscriber: Downstream,
         completion: Subscribers.Completion<Downstream.Failure>
     )

     func didReceive<Downstream: Subscriber>(
         subscriber: Downstream,
         completion: Subscribers.Completion<Downstream.Failure>
     )

     func willRequest(subscription: Subscription, _ demand: Subscribers.Demand)

     func didRequest(subscription: Subscription, _ demand: Subscribers.Demand)

     func willCancel(subscription: Subscription)

     func didCancel(subscription: Subscription)
 }

extension _Introspection {

    public func willReceive<Upstream: Publisher, Downstream: Subscriber>(
        publisher: Upstream,
        subscriber: Downstream
    ) where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input {}

    public func didReceive<Upstream: Publisher, Downstream: Subscriber>(
        publisher: Upstream,
        subscriber: Downstream
    ) where Upstream.Failure == Downstream.Failure, Upstream.Output == Downstream.Input {}

    public func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                    subscription: Subscription) {}

    public func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                   subscription: Subscription) {}

    public func willReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                    input: Downstream.Input) {}

    public func didReceive<Downstream: Subscriber>(subscriber: Downstream,
                                                   input: Downstream.Input,
                                                   resultingDemand: Subscribers.Demand) {}

    public func willReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        completion: Subscribers.Completion<Downstream.Failure>
    ) {}

    public func didReceive<Downstream: Subscriber>(
        subscriber: Downstream,
        completion: Subscribers.Completion<Downstream.Failure>
    ) {}

    public func willRequest(subscription: Subscription, _ demand: Subscribers.Demand) {}

    public func didRequest(subscription: Subscription, _ demand: Subscribers.Demand) {}

    public func willCancel(subscription: Subscription) {}

    public func didCancel(subscription: Subscription) {}

    public func enable() {
        DebugHook.enable(self)
    }

    public func disable() {
        DebugHook.disable(self)
    }

    public var isEnabled: Bool {
        return DebugHook.handlerIsEnabled(self)
    }
}
