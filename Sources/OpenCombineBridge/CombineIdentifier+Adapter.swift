#if canImport(Combine) && canImport(OpenCombine)
import Combine
import OpenCombine

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private func _rawValue(for id: Combine.CombineIdentifier) -> UInt64 {
  Mirror(reflecting: id).children.first(where: { $0.label == "rawValue" })!.value as! UInt64
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private func _rawValue(for id: OpenCombine.CombineIdentifier) -> UInt64 {
  Mirror(reflecting: id).children.first(where: { $0.label == "rawValue" })!.value as! UInt64
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private struct _CombineIdentifierProxy {
  init(_ object: OpenCombine.CustomCombineIdentifierConvertible) {
    self.init(object.combineIdentifier)
  }
  
  init(_ object: Combine.CustomCombineIdentifierConvertible) {
    self.init(object.combineIdentifier)
  }
  
  init(_ combineIdentifier: OpenCombine.CombineIdentifier) {
    self.init(rawValue: _rawValue(for: combineIdentifier))
  }
  
  init(_ combineIdentifier: Combine.CombineIdentifier) {
    self.init(rawValue: _rawValue(for: combineIdentifier))
  }
  
  init(rawValue: UInt64) {
    self.rawValue = rawValue
  }
  
  var rawValue: UInt64
  
  var combine: Combine.CombineIdentifier {
    return copyValue(
      of: self,
      as: Combine.CombineIdentifier()
    )
  }
  
  var ocombine: OpenCombine.CombineIdentifier {
    return copyValue(
      of: self,
      as: OpenCombine.CombineIdentifier()
    )
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension OpenCombine.CombineIdentifier {
  public var combine: Combine.CombineIdentifier {
    _CombineIdentifierProxy(self).combine
  }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Combine.CombineIdentifier {
  public var ocombine: OpenCombine.CombineIdentifier {
    _CombineIdentifierProxy(self).ocombine
  }
}
#endif
