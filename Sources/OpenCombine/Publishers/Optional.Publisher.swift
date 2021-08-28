//
//  Optional.Publisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Optional {

    /// A namespace for disambiguation when both OpenCombine and Combine are imported.
    ///
    /// Combine extends `Optional` with a nested type `Publisher`.
    /// If you import both OpenCombine and Combine (either explicitly or implicitly,
    /// e. g. when importing Foundation), you will not be able to write
    /// `Optional<Int>.Publisher`, because Swift is unable to understand
    /// which `Publisher` you're referring to.
    ///
    /// So you have to write `Optional<Int>.OCombine.Publisher`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine {

        fileprivate let optional: Optional

        fileprivate init(_ optional: Optional) {
            self.optional = optional
        }

        public var publisher: Publisher {
            return Publisher(optional)
        }

        /// The type of a Combine publisher that publishes the value of a Swift optional
        /// instance to each subscriber exactly once, if the instance has any value at
        /// all.
        ///
        /// In contrast with the `Just` publisher, which always produces a single value,
        /// this publisher might not send any values and instead finish normally,
        /// if `output` is `nil`.
        public struct Publisher: OpenCombine.Publisher {

            /// The kind of value published by this publisher.
            ///
            /// This publisher produces the type wrapped by the optional.
            public typealias Output = Wrapped

            /// The kind of error this publisher might publish.
            ///
            /// The optional publisher never produces errors.
            public typealias Failure = Never

            /// The output to deliver to each subscriber.
            public let output: Wrapped?

            /// Creates a publisher to emit the value of the optional, or to finish
            /// immediately if the optional doesn't have a value.
            ///
            /// - Parameter output: The result to deliver to each subscriber.
            public init(_ output: Output?) {
                self.output = output
            }

            /// Implements the Publisher protocol by accepting the subscriber and
            /// immediately publishing the optional’s value if it has one, or finishing
            /// normally if it doesn’t.
            ///
            /// - Parameter subscriber: The subscriber to add.
            public func receive<Downstream: Subscriber>(subscriber: Downstream)
                where Output == Downstream.Input, Failure == Downstream.Failure
            {
                if let output = output {
                    subscriber.receive(subscription: Inner(value: output,
                                                           downstream: subscriber))
                } else {
                    subscriber.receive(subscription: Subscriptions.empty)
                    subscriber.receive(completion: .finished)
                }
            }
        }
    }

    public var ocombine: OCombine {
        return .init(self)
    }

#if !canImport(Combine)
    /// The type of a Combine publisher that publishes the value of a Swift optional
    /// instance to each subscriber exactly once, if the instance has any value at
    /// all.
    ///
    /// In contrast with the `Just` publisher, which always produces a single value,
    /// this publisher might not send any values and instead finish normally,
    /// if `output` is `nil`.
    public typealias Publisher = OCombine.Publisher

    public var publisher: Publisher {
        return Publisher(self)
    }
#endif
}

extension Optional.OCombine {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Wrapped
    {
        // NOTE: this class has been audited for thread safety.
        // Combine doesn't use any locking here.

        private var downstream: Downstream?
        private let output: Wrapped

        init(value: Wrapped, downstream: Downstream) {
            self.output = value
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            guard let downstream = self.downstream.take() else { return }
            _ = downstream.receive(output)
            downstream.receive(completion: .finished)
        }

        func cancel() {
            downstream = nil
        }

        var description: String { return "Optional" }

        var customMirror: Mirror {
            return Mirror(self, unlabeledChildren: CollectionOfOne(output))
        }

        var playgroundDescription: Any { return description }
    }
}

extension Optional.OCombine.Publisher: Equatable where Wrapped: Equatable {}

extension Optional.OCombine.Publisher where Wrapped: Equatable {

    public func contains(_ output: Output) -> Optional<Bool>.OCombine.Publisher {
        return .init(self.output.map { $0 == output })
    }

    public func removeDuplicates() -> Optional<Wrapped>.OCombine.Publisher {
        return self
    }
}

extension Optional.OCombine.Publisher where Wrapped: Comparable {

    public func min() -> Optional<Wrapped>.OCombine.Publisher {
        return self
    }

    public func max() -> Optional<Wrapped>.OCombine.Publisher {
        return self
    }
}

extension Optional.OCombine.Publisher {

    public func allSatisfy(
        _ predicate: (Output) -> Bool
    ) -> Optional<Bool>.OCombine.Publisher {
        return .init(self.output.map(predicate))
    }

    public func collect() -> Optional<[Output]>.OCombine.Publisher {
        return .init(self.output.map { [$0] } ?? [])
    }

    public func compactMap<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult?
    ) -> Optional<ElementOfResult>.OCombine.Publisher {
        return .init(self.output.flatMap(transform))
    }

    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return self
    }

    public func max(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return self
    }

    public func contains(
        where predicate: (Output) -> Bool
    ) -> Optional<Bool>.OCombine.Publisher {
        return .init(self.output.map(predicate))
    }

    public func count() -> Optional<Int>.OCombine.Publisher {
        return .init(self.output.map { _ in 1 })
    }

    public func dropFirst(_ count: Int = 1) -> Optional<Output>.OCombine.Publisher {
        precondition(count >= 0, "count must not be negative")
        return .init(self.output.flatMap { count == 0 ? $0 : nil })
    }

    public func drop(
        while predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(self.output.flatMap { predicate($0) ? nil : $0 })
    }

    public func first() -> Optional<Output>.OCombine.Publisher {
        return self
    }

    public func first(
        where predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(output.flatMap { predicate($0) ? $0 : nil })
    }

    public func last() -> Optional<Output>.OCombine.Publisher {
        return self
    }

    public func last(
        where predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(output.flatMap { predicate($0) ? $0 : nil })
    }

    public func filter(
        _ isIncluded: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(output.flatMap { isIncluded($0) ? $0 : nil })
    }

    public func ignoreOutput() -> Empty<Output, Failure> {
        return .init()
    }

    public func map<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult
    ) -> Optional<ElementOfResult>.OCombine.Publisher {
        return .init(output.map(transform))
    }

    public func output(at index: Int) -> Optional<Output>.OCombine.Publisher {
        precondition(index >= 0, "index must not be negative")
        return .init(output.flatMap { index == 0 ? $0 : nil })
    }

    public func output<RangeExpression: Swift.RangeExpression>(
        in range: RangeExpression
    ) -> Optional<Output>.OCombine.Publisher where RangeExpression.Bound == Int {
        let range = range.relative(to: 0 ..< Int.max)
        precondition(range.lowerBound >= 0, "lowerBound must not be negative")

        // I don't know why, but Combine has this precondition
        precondition(range.upperBound < .max - 1)
        return .init(
            output.flatMap { (range.lowerBound == 0 && range.upperBound != 0) ? $0 : nil }
        )
    }

    public func prefix(_ maxLength: Int) -> Optional<Output>.OCombine.Publisher {
        precondition(maxLength >= 0, "maxLength must not be negative")
        return .init(output.flatMap { maxLength > 0 ? $0 : nil })
    }

    public func prefix(
        while predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(output.flatMap { predicate($0) ? $0 : nil })
    }

    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) -> Accumulator
    ) -> Optional<Accumulator>.OCombine.Publisher {
        return .init(output.map { nextPartialResult(initialResult, $0) })
    }

    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) -> ElementOfResult
    ) -> Optional<ElementOfResult>.OCombine.Publisher {
        return .init(output.map { nextPartialResult(initialResult, $0) })
    }

    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return self
    }

    public func replaceError(with output: Output) -> Optional<Output>.OCombine.Publisher {
        return self
    }

    public func replaceEmpty(with output: Output) -> Just<Output> {
        return .init(self.output ?? output)
    }

    public func retry(_ times: Int) -> Optional<Output>.OCombine.Publisher {
        return self
    }
}
