#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct SubscriberAdapter<Subscriber> {
  internal init(_ subscriber: Subscriber) {
    self.subscriber = subscriber
  }
  
  public let subscriber: Subscriber
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberAdapter where Subscriber: OpenCombine.Subscriber {
  public static func subscriber(
    _ subscriber: Subscriber
  ) -> SubscriberAdapter<Subscriber> {
    SubscriberAdapter<Subscriber>(subscriber)
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberAdapter where Subscriber: Combine.Subscriber {
  public static func subscriber(
    _ subscriber: Subscriber
  ) -> SubscriberAdapter<Subscriber> {
    SubscriberAdapter<Subscriber>(subscriber)
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberAdapter: Combine.CustomCombineIdentifierConvertible
where Subscriber: OpenCombine.CustomCombineIdentifierConvertible {
  public var combineIdentifier: Combine.CombineIdentifier {
    subscriber.combineIdentifier.combine
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberAdapter: OpenCombine.CustomCombineIdentifierConvertible
where Subscriber: Combine.CustomCombineIdentifierConvertible {
  public var combineIdentifier: OpenCombine.CombineIdentifier {
    subscriber.combineIdentifier.ocombine
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberAdapter: OpenCombine.Subscriber
where Subscriber: Combine.Subscriber {
  public typealias Input = Subscriber.Input
  public typealias Failure = Subscriber.Failure
  
  public var combineIdentifier: OpenCombine.CombineIdentifier {
    subscriber.combineIdentifier.ocombine
  }
  
  public func receive(subscription: OpenCombine.Subscription) {
    subscriber.receive(subscription: SubscriptionAdapter.subscription(subscription))
  }
  
  public func receive(_ input: Subscriber.Input) -> OpenCombine.Subscribers.Demand {
    return subscriber.receive(input).ocombine
  }
  
  public func receive(completion: OpenCombine.Subscribers.Completion<Subscriber.Failure>) {
    subscriber.receive(completion: completion.combine)
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberAdapter: Combine.Subscriber
where Subscriber: OpenCombine.Subscriber {
  public typealias Input = Subscriber.Input
  public typealias Failure = Subscriber.Failure
  
  public var combineIdentifier: Combine.CombineIdentifier {
    subscriber.combineIdentifier.combine
  }
  
  public func receive(subscription: Combine.Subscription) {
    subscriber.receive(subscription: SubscriptionAdapter.subscription(subscription))
  }
  
  public func receive(_ input: Subscriber.Input) -> Combine.Subscribers.Demand {
    return subscriber.receive(input).combine
  }
  
  public func receive(completion: Combine.Subscribers.Completion<Subscriber.Failure>) {
    subscriber.receive(completion: completion.ocombine)
  }
}

#endif
