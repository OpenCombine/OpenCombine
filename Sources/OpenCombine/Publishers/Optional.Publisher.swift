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

        /// A publisher that publishes an optional value to each subscriber
        /// exactly once, if the optional has a value.
        ///
        /// In contrast with `Just`, an `Optional` publisher may send
        /// no value before completion.
        public struct Publisher: OpenCombine.Publisher {

            public typealias Output = Wrapped

            public typealias Failure = Never

            /// The result to deliver to each subscriber.
            public let output: Wrapped?

            /// Creates a publisher to emit the optional value of a successful result,
            /// or fail with an error.
            ///
            /// - Parameter result: The result to deliver to each subscriber.
            public init(_ output: Output?) {
                self.output = output
            }

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

#if !canImport(Combine)
    /// A publisher that publishes an optional value to each subscriber
    /// exactly once, if the optional has a value.
    ///
    /// In contrast with `Just`, an `Optional` publisher may send
    /// no value before completion.
    public typealias Publisher = OCombine.Publisher
#endif
}

extension Optional.OCombine {
    private final class Inner<Downstream: Subscriber>: Subscription,
                                                       CustomStringConvertible,
                                                       CustomReflectable
    {
        private let _output: Downstream.Input
        private var _downstream: Downstream?

        init(value: Downstream.Input, downstream: Downstream) {
            _output = value
            _downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {
            if let downstream = _downstream, demand > 0 {
                _ = downstream.receive(_output)
                downstream.receive(completion: .finished)
                _downstream = nil
            }
        }

        func cancel() {
            _downstream = nil
        }

        var description: String { return "Optional" }

        var customMirror: Mirror {
            return Mirror(self, unlabeledChildren: CollectionOfOne(_output))
        }
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
        precondition(range.lowerBound >= 0, "lowerBould must not be negative")

        // I don't know why, but Combine has this precondition
        precondition(range.upperBound < .max - 1)
        return .init(output.flatMap { range.contains(0) ? $0 : nil })
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
