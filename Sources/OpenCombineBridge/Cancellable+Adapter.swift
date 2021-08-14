#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private struct CancellableAdapter: OpenCombine.Cancellable, Combine.Cancellable {
  public init(_ cancellable: OpenCombine.Cancellable) {
    self._cancel = cancellable.cancel
  }
  
  public init(_ cancellable: Combine.Cancellable) {
    self._cancel = cancellable.cancel
  }
  
  private init(cancel: @escaping () -> Void) {
    self._cancel = cancel
  }
  
  private let _cancel: () -> Void
  
  func cancel() { _cancel() }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension OpenCombine.Cancellable {
  public var combine: OpenCombine.Cancellable {
    CancellableAdapter(self)
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Combine.Cancellable {
  public var ocombine: OpenCombine.Cancellable {
    CancellableAdapter(self)
  }
}
#endif
