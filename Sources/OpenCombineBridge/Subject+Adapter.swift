#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public final class SubjectAdapter<Subject> {
  internal init(_ subject: Subject) {
    self.subject = subject
  }
  
  let subject: Subject
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubjectAdapter: Combine.Publisher where Subject: OpenCombine.Publisher {
  public typealias Output = Subject.Output
  public typealias Failure = Subject.Failure
  
  public func receive<S>(subscriber: S)
  where S: Combine.Subscriber, Subject.Failure == S.Failure, Subject.Output == S.Input {
    subject.receive(subscriber: SubscriberAdapter.subscriber(subscriber))
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubjectAdapter: OpenCombine.Publisher where Subject: Combine.Publisher {
  public typealias Output = Subject.Output
  public typealias Failure = Subject.Failure
  
  public func receive<S>(subscriber: S)
  where S: OpenCombine.Subscriber, Subject.Failure == S.Failure, Subject.Output == S.Input {
    subject.receive(subscriber: SubscriberAdapter.subscriber(subscriber))
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubjectAdapter: Combine.Subject where Subject: OpenCombine.Subject {
  public func send(_ value: Subject.Output) {
    subject.send(value)
  }
  
  public func send(completion: Combine.Subscribers.Completion<Subject.Failure>) {
    subject.send(completion: completion.ocombine)
  }
  
  public func send(subscription: Combine.Subscription) {
    subject.send(subscription: SubscriptionAdapter.subscription(subscription))
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubjectAdapter: OpenCombine.Subject where Subject: Combine.Subject {
  public func send(_ value: Subject.Output) {
    subject.send(value)
  }
  
  public func send(completion: OpenCombine.Subscribers.Completion<Subject.Failure>) {
    subject.send(completion: completion.combine)
  }
  
  public func send(subscription: OpenCombine.Subscription) {
    subject.send(subscription: SubscriptionAdapter.subscription(subscription))
  }
}
#endif
