// From /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib/swift/Foundation.swiftmodule/x86_64.swiftinterface
// swift-interface-format-version: 1.0
// swift-compiler-version: Apple Swift version 5.1.1 (swiftlang-1100.8.275.1 clang-1100.0.32.1)
// swift-module-flags: -target x86_64-apple-macosx10.15 -enable-objc-interop -autolink-force-load -enable-library-evolution -module-link-name swiftFoundation -swift-version 5 -O -enforce-exclusivity=unchecked -module-name Foundation

public typealias Published = Combine.Published

public typealias ObservableObject = Combine.ObservableObject

public protocol _KeyValueCodingAndObservingPublishing {
}

extension NSObject : Foundation._KeyValueCodingAndObservingPublishing {
}

extension _KeyValueCodingAndObservingPublishing where Self : ObjectiveC.NSObject {
  public func publisher<Value>(for keyPath: Swift.KeyPath<Self, Value>, options: Foundation.NSKeyValueObservingOptions = [.initial, .new]) -> ObjectiveC.NSObject.KeyValueObservingPublisher<Self, Value>
}

extension NSObject.KeyValueObservingPublisher {
  public func didChange() -> Combine.Publishers.Map<ObjectiveC.NSObject.KeyValueObservingPublisher<Subject, Value>, Swift.Void>
}

extension NSObject {
  public struct KeyValueObservingPublisher<Subject, Value> : Swift.Equatable where Subject : ObjectiveC.NSObject {
    public let object: Subject
    public let keyPath: Swift.KeyPath<Subject, Value>
    public let options: Foundation.NSKeyValueObservingOptions
    public init(object: Subject, keyPath: Swift.KeyPath<Subject, Value>, options: Foundation.NSKeyValueObservingOptions)
    public static func == (lhs: ObjectiveC.NSObject.KeyValueObservingPublisher<Subject, Value>, rhs: ObjectiveC.NSObject.KeyValueObservingPublisher<Subject, Value>) -> Swift.Bool
  }
}

extension NSObject.KeyValueObservingPublisher : Combine.Publisher {
  public typealias Output = Value
  public typealias Failure = Swift.Never
  public func receive<S>(subscriber: S) where Value == S.Input, S : Combine.Subscriber, S.Failure == ObjectiveC.NSObject.KeyValueObservingPublisher<Subject, Value>.Failure
}

