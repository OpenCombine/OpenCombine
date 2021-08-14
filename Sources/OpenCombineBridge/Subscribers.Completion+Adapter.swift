#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension OpenCombine.Subscribers.Completion {
  public var combine: Combine.Subscribers.Completion<Failure> {
    switch self {
    case .finished:
      return .finished
    case .failure(let error):
      return .failure(error)
    }
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Combine.Subscribers.Completion {
  public var ocombine: OpenCombine.Subscribers.Completion<Failure> {
    switch self {
    case .finished:
      return .finished
    case .failure(let error):
      return .failure(error)
    }
  }
}
#endif
