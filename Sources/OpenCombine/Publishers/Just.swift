//
//  Just.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

/// A publisher that emits an output to each subscriber just once, and then finishes.
///
/// You can use a `Just` publisher to start a chain of publishers. A `Just` publisher is
/// also useful when replacing a value with `Publishers.Catch`.
///
/// In contrast with `Result.Publisher`, a `Just` publisher can’t fail with an error.
/// And unlike `Optional.Publisher`, a `Just` publisher always produces a value.
public struct Just<Output>: Publisher {

    public typealias Failure = Never

    /// The one element that the publisher emits.
    public let output: Output

    /// Initializes a publisher that emits the specified output just once.
    ///
    /// - Parameter output: The one element that the publisher emits.
    public init(_ output: Output) {
        self.output = output
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Never
    {
        subscriber.receive(subscription: Inner(value: output, downstream: subscriber))
    }
}

extension Just: Equatable where Output: Equatable {}

extension Just where Output: Comparable {

    public func min() -> Just<Output> {
        return self
    }

    public func max() -> Just<Output> {
        return self
    }
}

extension Just where Output: Equatable {

    public func contains(_ output: Output) -> Just<Bool> {
        return .init(self.output == output)
    }

    public func removeDuplicates() -> Just<Output> {
        return self
    }
}

extension Just {

    public func allSatisfy(_ predicate: (Output) -> Bool) -> Just<Bool> {
        return .init(predicate(output))
    }

    public func tryAllSatisfy(
        _ predicate: (Output) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try predicate(output) })
    }

    public func contains(where predicate: (Output) -> Bool) -> Just<Bool> {
        return .init(predicate(output))
    }

    public func tryContains(
        where predicate: (Output) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try predicate(output) })
    }

    public func collect() -> Just<[Output]> {
        return .init([output])
    }

    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Just<Output> {
        return self
    }

    public func max(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Just<Output> {
        return self
    }

    public func count() -> Just<Int> {
        return .init(1)
    }

    public func dropFirst(_ count: Int = 1) -> Optional<Output>.OCombine.Publisher {
        precondition(count >= 0, "count must not be negative")
        return .init(count > 0 ? nil : self.output)
    }

    public func drop(
        while predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? nil : output)
    }

    public func first() -> Just<Output> {
        return self
    }

    public func first(
        where predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? output : nil)
    }

    public func last() -> Just<Output> {
        return self
    }

    public func last(
        where predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? output : nil)
    }

    public func ignoreOutput() -> Empty<Output, Never> {
        return .init()
    }

    public func map<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult
    ) -> Just<ElementOfResult> {
        return .init(transform(output))
    }

    public func tryMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult
    ) -> Result<ElementOfResult, Error>.OCombine.Publisher {
        return .init(Result { try transform(output) })
    }

    public func compactMap<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult?
    ) -> Optional<ElementOfResult>.OCombine.Publisher {
        return .init(transform(output))
    }

    public func filter(
        _ isIncluded: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(isIncluded(output) ? output : nil)
    }

    public func output(at index: Int) -> Optional<Output>.OCombine.Publisher {
        precondition(index >= 0, "index must not be negative")
        return .init(index == 0 ? output : nil)
    }

    public func output<RangeExpression: Swift.RangeExpression>(
        in range: RangeExpression
    ) -> Optional<Output>.OCombine.Publisher where RangeExpression.Bound == Int {
        // TODO: Broken in Apple's Combine? (FB6169621)
        // Empty range should result in a nil
        let range = range.relative(to: 0..<Int.max)
        return .init(range.lowerBound == 0 ? output : nil)
        // The above implementation is used for compatibility.
        //
        // It actually probably should be just this:
        // return .init(range.contains(0) ? output : nil)
    }

    public func prefix(_ maxLength: Int) -> Optional<Output>.OCombine.Publisher {
        precondition(maxLength >= 0, "maxLength must not be negative")
        return .init(maxLength > 0 ? output : nil)
    }

    public func prefix(
        while predicate: (Output) -> Bool
    ) -> Optional<Output>.OCombine.Publisher {
        return .init(predicate(output) ? output : nil)
    }

    public func setFailureType<Failure: Error>(
        to failureType: Failure.Type
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return .init(output)
    }

    public func mapError<Failure: Error>(
        _ transform: (Never) -> Failure
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return .init(output)
    }

    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Just<Output> {
        return self
    }

    public func tryRemoveDuplicates(
        by predicate: (Output, Output) throws -> Bool
    ) -> Result<Output, Error>.OCombine.Publisher {
        return .init(Result { try _ = predicate(output, output); return output })
    }

    public func replaceError(with output: Output) -> Just<Output> {
        return self
    }

    public func replaceEmpty(with output: Output) -> Just<Output> {
        return self
    }

    public func retry(_ times: Int) -> Just<Output> {
        return self
    }

    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) -> Accumulator
    ) -> Result<Accumulator, Never>.OCombine.Publisher {
        return .init(nextPartialResult(initialResult, output))
    }

    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) throws -> Accumulator
    ) -> Result<Accumulator, Error>.OCombine.Publisher {
        return .init(Result { try nextPartialResult(initialResult, output) })
    }

    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) -> ElementOfResult
    ) -> Result<ElementOfResult, Never>.OCombine.Publisher {
        return .init(nextPartialResult(initialResult, output))
    }

    public func tryScan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) throws -> ElementOfResult
    ) -> Result<ElementOfResult, Error>.OCombine.Publisher {
        return .init(Result { try nextPartialResult(initialResult, output) })
    }

    public func prepend(_ elements: Output...) -> Publishers.Sequence<[Output], Never> {
        return prepend(elements)
    }

    public func prepend<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Sequence<[Output], Never> where Output == Elements.Element {
        return .init(sequence: elements + [output])
    }

    public func append(_ elements: Output...) -> Publishers.Sequence<[Output], Never> {
        return append(elements)
    }

    public func append<Elements: Sequence>(
        _ elements: Elements
    ) -> Publishers.Sequence<[Output], Never> where Output == Elements.Element {
        return .init(sequence: [output] + elements)
    }
}

extension Just {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output
    {
        // NOTE: this class has been audited for thread safety.
        // Combine doesn't use any locking here.

        private var downstream: Downstream?
        private let value: Output

        fileprivate init(value: Output, downstream: Downstream) {
            self.downstream = downstream
            self.value = value
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            guard let downstream = self.downstream.take() else { return }
            _ = downstream.receive(value)
            downstream.receive(completion: .finished)
        }

        func cancel() {
            downstream = nil
        }

        var description: String { return "Just" }

        var customMirror: Mirror {
            return Mirror(self, unlabeledChildren: CollectionOfOne(value))
        }

        var playgroundDescription: Any { return description }
    }
}
