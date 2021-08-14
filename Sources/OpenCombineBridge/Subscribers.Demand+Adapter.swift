#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private func _rawValue(for demand: Combine.Subscribers.Demand) -> UInt {
  Mirror(reflecting: demand).children.first(where: { $0.label == "rawValue" })!.value as! UInt
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private func _rawValue(for demand: OpenCombine.Subscribers.Demand) -> UInt {
  Mirror(reflecting: demand).children.first(where: { $0.label == "rawValue" })!.value as! UInt
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension OpenCombine.Subscribers.Demand {
  public var combine: Combine.Subscribers.Demand {
    copyValue(
      of: self,
      as: Combine.Subscribers.Demand.none
    )
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Combine.Subscribers.Demand {
  public var ocombine: OpenCombine.Subscribers.Demand {
    copyValue(
      of: self,
      as: OpenCombine.Subscribers.Demand.none
    )
  }
}
#endif
