//
//  Publishers.Once.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Publishers {

    /// A publisher that publishes an output to each subscriber exactly once then finishes, or fails immediately without
    /// producing any elements.
    ///
    /// If `result` is `.success`, then `Once` waits until it receives a request for at least 1 value before sending
    /// the output. If `result` is `.failure`, then `Once` sends the failure immediately upon subscription.
    ///
    /// In contrast with `Just`, a `Once` publisher can terminate with an error instead of sending a value.
    /// In contrast with `Optional`, a `Once` publisher always sends one value (unless it terminates with an error).
    public struct Once<Output, Failure: Error>: Publisher {

        /// The result to deliver to each subscriber.
        public let result: Result<Output, Failure>

        /// Creates a publisher that delivers the specified result.
        ///
        /// If the result is `.success`, the `Once` publisher sends the specified output to all subscribers and
        /// finishes normally. If the result is `.failure`, then the publisher fails immediately with the specified error.
        /// - Parameter result: The result to deliver to each subscriber.
        public init(_ result: Result<Output, Failure>) {
            self.result = result
        }

        /// Creates a publisher that sends the specified output to all subscribers and finishes normally.
        ///
        /// - Parameter output: The output to deliver to each subscriber.
        public init(_ output: Output) {
            self.init(.success(output))
        }

        /// Creates a publisher that immediately terminates upon subscription with the given failure.
        ///
        /// - Parameter failure: The failure to send when terminating.
        public init(_ failure: Failure) {
            self.init(.failure(failure))
        }

        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where SubscriberType.Input == Output, SubscriberType.Failure == Failure
        {
            switch result {
            case .success(let value):
                subscriber.receive(subscription: Inner(value: value,
                                                       downstream: subscriber))
            case .failure(let failure):
                subscriber.receive(subscription: Subscriptions.empty)
                subscriber.receive(completion: .failure(failure))
            }
        }
    }
}

private final class Inner<SubscriberType: Subscriber>: Subscription,
                                          CustomStringConvertible,
                                          CustomReflectable
{
    private let _output: SubscriberType.Input
    private var _downstream: SubscriberType?

    init(value: SubscriberType.Input, downstream: SubscriberType) {
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

    var description: String { return "Once" }

    var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: CollectionOfOne(_output))
    }
}

extension Publishers.Once: Equatable where Output: Equatable, Failure: Equatable {}

extension Publishers.Once where Output: Equatable {

    public func contains(_ output: Output) -> Publishers.Once<Bool, Failure> {
        return Publishers.Once(result.map { $0 == output })
    }

    public func removeDuplicates() -> Publishers.Once<Output, Failure> {
        return self
    }
}

extension Publishers.Once where Output: Comparable {

    public func min() -> Publishers.Once<Output, Failure> {
        return self
    }

    public func max() -> Publishers.Once<Output, Failure> {
        return self
    }
}

extension Publishers.Once {

    public func allSatisfy(
        _ predicate: (Output) -> Bool
    ) -> Publishers.Once<Bool, Failure> {
        return Publishers.Once(result.map(predicate))
    }

    public func tryAllSatisfy(
        _ predicate: (Output) throws -> Bool
    ) -> Publishers.Once<Bool, Error> {
        return Publishers.Once(result.tryMap(predicate))
    }

    public func contains(
        where predicate: (Output) -> Bool
    ) -> Publishers.Once<Bool, Failure> {
        return Publishers.Once(result.map(predicate))
    }

    public func tryContains(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Once<Bool, Error> {
        return Publishers.Once(result.tryMap(predicate))
    }

    public func collect() -> Publishers.Once<[Output], Failure> {
        return Publishers.Once(result.map { [$0] })
    }

    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func tryMin(
        by areInIncreasingOrder: (Output, Output) throws -> Bool
    ) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func max(
        by areInIncreasingOrder: (Output, Output
    ) -> Bool) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func tryMax(
        by areInIncreasingOrder: (Output, Output) throws -> Bool
    ) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func count() -> Publishers.Once<Int, Failure> {
        return Publishers.Once(result.map { _ in 1 })
    }

    public func dropFirst(_ count: Int = 1) -> Publishers.Optional<Output, Failure> {
        precondition(count >= 0, "count must not be negative")
        return Publishers.Optional((try? result.get()).flatMap { count == 0 ? $0 : nil })
    }

    public func drop(
        while predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { predicate($0) ? nil : $0 })
    }

    public func tryDrop(
        while predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(result.tryMap { try predicate($0) ? nil : $0 })
    }

    public func first() -> Publishers.Once<Output, Failure> {
        return self
    }

    public func first(
        where predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { predicate($0) ? $0 : nil })
    }

    public func tryFirst(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(result.tryMap { try predicate($0) ? $0 : nil })
    }

    public func last() -> Publishers.Once<Output, Failure> {
        return self
    }

    public func last(
        where predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { predicate($0) ? $0 : nil })
    }

    public func tryLast(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(result.tryMap { try predicate($0) ? $0 : nil })
    }

    public func filter(
        _ isIncluded: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { isIncluded($0) ? $0 : nil })
    }

    public func tryFilter(
        _ isIncluded: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(result.tryMap { try isIncluded($0) ? $0 : nil })
    }

    public func ignoreOutput() -> Publishers.Empty<Output, Failure> {
        return Publishers.Empty()
    }

    public func map<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult
    ) -> Publishers.Once<ElementOfResult, Failure> {
        return Publishers.Once(result.map(transform))
    }

    public func tryMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult
    ) -> Publishers.Once<ElementOfResult, Error> {
        return Publishers.Once(result.tryMap(transform))
    }

    public func compactMap<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult?
    ) -> Publishers.Optional<ElementOfResult, Failure> {
        return Publishers.Optional(result.map(transform))
    }

    public func tryCompactMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult?
    ) -> Publishers.Optional<ElementOfResult, Error> {
        return Publishers.Optional(result.tryMap(transform))
    }

    public func mapError<TransformedFailure: Error>(
        _ transform: (Failure) -> TransformedFailure
    ) -> Publishers.Once<Output, TransformedFailure> {
        return Publishers.Once(result.mapError(transform))
    }

    public func output(at index: Int) -> Publishers.Optional<Output, Failure> {
        precondition(index >= 0, "index must not be negative")
        return Publishers.Optional(result.map { index == 0 ? $0 : nil })
    }

    public func output<RangeExpr: RangeExpression>(
        in range: RangeExpr
    ) -> Publishers.Optional<Output, Failure> where RangeExpr.Bound == Int {
        // TODO: Broken in Apple's Combine? (FB6169621)
        // Empty range should result in a nil
        let range = range.relative(to: 0..<Int.max)
        return Publishers.Optional(
            result.map { range.lowerBound == 0 ? $0 : nil }
        )
        // The above implementation is used for compatibility.
        //
        // It actually probably should be just this:
        // return Publishers.Optional(
        //     result.map { range.contains(0) ? $0 : nil }
        // )
    }

    public func prefix(_ maxLength: Int) -> Publishers.Optional<Output, Failure> {
        precondition(maxLength >= 0, "maxLength must not be negative")
        // TODO: Seems broken in Apple's Combine (FB6168300)
        return Publishers.Optional(
            result.map { maxLength == 0 ? $0 : nil }
        )
        // The above implementation is used for compatibility.
        //
        // It actually should be the following:
        // return Publishers.Optional(
        //     result.map { $0.flatMap { maxLength > 0 ? $0 : nil } }
        // )
    }

    public func prefix(
        while predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { predicate($0) ? $0 : nil })
    }

    public func tryPrefix(
        while predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(result.tryMap { try predicate($0) ? $0 : nil })
    }

    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func tryRemoveDuplicates(
        by predicate: (Output, Output) throws -> Bool
    ) -> Publishers.Once<Output, Error> {
        return Publishers.Once(result.mapError { $0 })
    }

    public func replaceError(with output: Output) -> Publishers.Once<Output, Never> {
        return Publishers.Once(.success(result.unwrapOr(output)))
    }

    public func replaceEmpty(with output: Output) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func retry(_ times: Int) -> Publishers.Once<Output, Failure> {
        return self
    }

    public func retry() -> Publishers.Once<Output, Failure> {
        return self
    }

    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) -> Accumulator
    ) -> Publishers.Once<Accumulator, Failure> {
        return Publishers.Once(result.map { nextPartialResult(initialResult, $0) })
    }

    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) throws -> Accumulator
    ) -> Publishers.Once<Accumulator, Error> {
        return Publishers.Once(result.tryMap { try nextPartialResult(initialResult, $0) })
    }

    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) -> ElementOfResult
    ) -> Publishers.Once<ElementOfResult, Failure> {
        return Publishers.Once(result.map { nextPartialResult(initialResult, $0) })
    }

    public func tryScan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) throws -> ElementOfResult
    ) -> Publishers.Once<ElementOfResult, Error> {
        return Publishers.Once(result.tryMap { try nextPartialResult(initialResult, $0) })
    }
}

extension Publishers.Once where Failure == Never {

    public func setFailureType<Failure: Error>(
        to failureType: Failure.Type
    ) -> Publishers.Once<Output, Failure> {
        return Publishers.Once(result.success)
    }
}
