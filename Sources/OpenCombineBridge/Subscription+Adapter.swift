#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct SubscriptionAdapter<Subscription> {
  internal init(_ subscription: Subscription) {
    self.subscription = subscription
  }
  public let subscription: Subscription
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriptionAdapter where Subscription == _OpenCombineSubscriptionWrapper {
  public static func subscription(
    _ subscription: OpenCombine.Subscription
  ) -> SubscriptionAdapter {
    return .init(_OpenCombineSubscriptionWrapper(subscription))
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriptionAdapter where Subscription == _CombineSubscriptionWrapper {
  public static func subscription(
    _ subscription: Combine.Subscription
  ) -> SubscriptionAdapter {
    return .init(_CombineSubscriptionWrapper(subscription))
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct _CombineSubscriptionWrapper: Combine.Subscription {
  public init(_ subscription: Combine.Subscription) {
    self.subscription = subscription
  }
  
  private let subscription: Combine.Subscription
  
  public func request(_ demand: Combine.Subscribers.Demand) {
    subscription.request(demand)
  }
  
  public func cancel() {
    subscription.cancel()
  }
  
  public var combineIdentifier: Combine.CombineIdentifier {
    subscription.combineIdentifier
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct _OpenCombineSubscriptionWrapper: OpenCombine.Subscription {
  public init(_ subscription: OpenCombine.Subscription) {
    self.subscription = subscription
  }
  
  private let subscription: OpenCombine.Subscription
  
  public func request(_ demand: OpenCombine.Subscribers.Demand) {
    subscription.request(demand)
  }
  
  public func cancel() {
    subscription.cancel()
  }
  
  public var combineIdentifier: OpenCombine.CombineIdentifier {
    subscription.combineIdentifier
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriptionAdapter:
  OpenCombine.Subscription,
  OpenCombine.Cancellable,
  OpenCombine.CustomCombineIdentifierConvertible
where Subscription: Combine.Subscription {
  public func request(_ demand: OpenCombine.Subscribers.Demand) {
    subscription.request(demand.combine)
  }
  
  public func cancel() {
    subscription.cancel()
  }
  
  public var combineIdentifier: OpenCombine.CombineIdentifier {
    subscription.combineIdentifier.ocombine
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriptionAdapter:
  Combine.Subscription,
  Combine.Cancellable,
  Combine.CustomCombineIdentifierConvertible
where Subscription: OpenCombine.Subscription {
  public func request(_ demand: Combine.Subscribers.Demand) {
    subscription.request(demand.ocombine)
  }
  
  public func cancel() {
    subscription.cancel()
  }
  
  public var combineIdentifier: Combine.CombineIdentifier {
    subscription.combineIdentifier.combine
  }
}

#endif
