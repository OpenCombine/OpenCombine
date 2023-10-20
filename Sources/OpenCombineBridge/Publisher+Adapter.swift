#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct PublisherAdapter<Publisher> {
  internal init(_ publisher: Publisher) {
    self.publisher = publisher
  }
  
  let publisher: Publisher
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PublisherAdapter: Combine.Publisher where Publisher: OpenCombine.Publisher {
  public typealias Output = Publisher.Output
  public typealias Failure = Publisher.Failure
  
  public func receive<S>(subscriber: S)
  where S: Combine.Subscriber, Publisher.Failure == S.Failure, Publisher.Output == S.Input {
    publisher.receive(subscriber: SubscriberAdapter.subscriber(subscriber))
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PublisherAdapter: OpenCombine.Publisher where Publisher: Combine.Publisher {
  public typealias Output = Publisher.Output
  public typealias Failure = Publisher.Failure
  
  public func receive<S>(subscriber: S)
  where S: OpenCombine.Subscriber, Publisher.Failure == S.Failure, Publisher.Output == S.Input {
    publisher.receive(subscriber: SubscriberAdapter.subscriber(subscriber))
  }
}
#endif
