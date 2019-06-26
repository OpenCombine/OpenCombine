//
//  Publishers.Optional.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Publishers {

    /// A publisher that publishes an optional value to each subscriber exactly once, if the optional has a value.
    ///
    /// If `result` is `.success`, and the value is non-nil, then `Optional` waits until receiving a request for
    /// at least 1 value before sending the output. If `result` is `.failure`, then `Optional` sends the failure
    /// immediately upon subscription. If `result` is `.success` and the value is nil, then `Optional` sends
    /// `.finished` immediately upon subscription.
    ///
    /// In contrast with `Just`, an `Optional` publisher can send an error.
    /// In contrast with `Once`, an `Optional` publisher can send zero values and finish normally, or send
    /// zero values and fail with an error.
    public struct Optional<Output, Failure: Error>: Publisher {
        // swiftlint:disable:previous syntactic_sugar

        /// The result to deliver to each subscriber.
        public let result: Result<Output?, Failure>

        /// Creates a publisher to emit the optional value of a successful result, or fail with an error.
        ///
        /// - Parameter result: The result to deliver to each subscriber.
        public init(_ result: Result<Output?, Failure>) {
            self.result = result
        }

        public init(_ output: Output?) {
            self.init(.success(output))
        }

        public init(_ failure: Failure) {
            self.init(.failure(failure))
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Output == SubscriberType.Input, Failure == SubscriberType.Failure
        {
            switch result {
            case .success(let value?):
                subscriber.receive(subscription: Inner(value: value,
                                                       downstream: subscriber))
            case .success(nil):
                subscriber.receive(subscription: Subscriptions.empty)
                subscriber.receive(completion: .finished)
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

    var description: String { return "Optional" }

    var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: CollectionOfOne(_output))
    }
}

extension Publishers.Optional: Equatable where Output: Equatable, Failure: Equatable {}

extension Publishers.Optional where Output: Equatable {

    public func contains(_ output: Output) -> Publishers.Optional<Bool, Failure> {
        return Publishers.Optional(result.map { $0 == output })
    }

    public func removeDuplicates() -> Publishers.Optional<Output, Failure> {
        return self
    }
}

extension Publishers.Optional where Output: Comparable {

    public func min() -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func max() -> Publishers.Optional<Output, Failure> {
        return self
    }
}

extension Publishers.Optional {

    public func allSatisfy(
        _ predicate: (Output) -> Bool
    ) -> Publishers.Optional<Bool, Failure> {
        return Publishers.Optional(result.map { $0.map(predicate) })
    }

    public func tryAllSatisfy(
        _ predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Bool, Error> {
        return Publishers.Optional(result.tryMap { try $0.map(predicate) })
    }

    public func collect() -> Publishers.Optional<[Output], Failure> {
        return Publishers.Optional(result.map { $0.map { [$0] } })
    }

    public func compactMap<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult?
    ) -> Publishers.Optional<ElementOfResult, Failure> {
        return Publishers.Optional(result.map { $0.flatMap(transform) })
    }

    public func tryCompactMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult?
        ) -> Publishers.Optional<ElementOfResult, Error> {
        return Publishers.Optional(result.tryMap { try $0.flatMap(transform) })
    }

    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func tryMin(
        by areInIncreasingOrder: (Output, Output) throws -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func max(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func tryMax(
        by areInIncreasingOrder: (Output, Output) throws -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func contains(
        where predicate: (Output) -> Bool
    ) -> Publishers.Optional<Bool, Failure> {
        return Publishers.Optional(result.map { $0.map(predicate) })
    }

    public func tryContains(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Bool, Error> {
        return Publishers.Optional(result.tryMap { try $0.map(predicate) })
    }

    public func count() -> Publishers.Optional<Int, Failure> {
        return Publishers.Optional(result.map { _ in 1 })
    }

    public func dropFirst(_ count: Int = 1) -> Publishers.Optional<Output, Failure> {
        precondition(count >= 0, "count must not be negative")
        return Publishers.Optional(try? result.get().flatMap { count == 0 ? $0 : nil })
    }

    public func drop(
        while predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { $0.flatMap { predicate($0) ? nil : $0 } })
    }

    public func tryDrop(
        while predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.flatMap { try predicate($0) ? nil : $0 } }
        )
    }

    public func first() -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func first(
        where predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { $0.flatMap { predicate($0) ? $0 : nil } })
    }

    public func tryFirst(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.flatMap { try predicate($0) ? $0 : nil } }
        )
    }

    public func last() -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func last(
        where predicate: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.map { $0.flatMap { predicate($0) ? $0 : nil } })
    }

    public func tryLast(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.flatMap { try predicate($0) ? $0 : nil } }
        )
    }

    public func filter(
        _ isIncluded: (Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(
            result.map { $0.flatMap { isIncluded($0) ? $0 : nil } }
        )
    }

    public func tryFilter(
        _ isIncluded: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.flatMap { try isIncluded($0) ? $0 : nil } }
        )
    }

    public func ignoreOutput() -> Publishers.Empty<Output, Failure> {
        return Publishers.Empty()
    }

    public func map<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult
    ) -> Publishers.Optional<ElementOfResult, Failure> {
        return Publishers.Optional(result.map { $0.map(transform) })
    }

    public func tryMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult
    ) -> Publishers.Optional<ElementOfResult, Error> {
        return Publishers.Optional(result.tryMap { try $0.map(transform) })
    }

    public func mapError<TransformedFailure: Error>(
        _ transform: (Failure) -> TransformedFailure
    ) -> Publishers.Optional<Output, TransformedFailure> {
        return Publishers.Optional(result.mapError(transform))
    }

    public func output(at index: Int) -> Publishers.Optional<Output, Failure> {
        precondition(index >= 0, "index must not be negative")
        return Publishers.Optional(result.map { $0.flatMap { index == 0 ? $0 : nil } })
    }

    public func output<RangeExpr: RangeExpression>(
        in range: RangeExpr
    ) -> Publishers.Optional<Output, Failure> where RangeExpr.Bound == Int {
        // TODO: Broken in Apple's Combine? (FB6169621)
        // Empty range should result in a nil
        let range = range.relative(to: 0..<Int.max)
        return Publishers.Optional(
            result.map { $0.flatMap { range.lowerBound == 0 ? $0 : nil } }
        )
        // The above implementation is used for compatibility.
        //
        // It actually probably should be just this:
//        return Publishers.Optional(
//            result.map { $0.flatMap { range.contains(0) ? $0 : nil } }
//        )
    }

    public func prefix(_ maxLength: Int) -> Publishers.Optional<Output, Failure> {
        precondition(maxLength >= 0, "maxLength must not be negative")
        // TODO: Seems broken in Apple's Combine (FB6168300)
        return Publishers.Optional(
            result.map { $0.flatMap { maxLength == 0 ? $0 : nil } }
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
        return Publishers.Optional(
            result.map { $0.flatMap { predicate($0) ? $0 : nil } }
        )
    }

    public func tryPrefix(
        while predicate: (Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.flatMap { try predicate($0) ? $0 : nil } }
        )
    }

    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) -> Accumulator
    ) -> Publishers.Optional<Accumulator, Failure> {
        return Publishers.Optional(
            result.map { $0.map { nextPartialResult(initialResult, $0) } }
        )
    }

    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) throws -> Accumulator
    ) -> Publishers.Optional<Accumulator, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.map { try nextPartialResult(initialResult, $0) } }
        )
    }

    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) -> ElementOfResult
    ) -> Publishers.Optional<ElementOfResult, Failure> {
        return Publishers.Optional(
            result.map { $0.map { nextPartialResult(initialResult, $0) } }
        )
    }

    public func tryScan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) throws -> ElementOfResult
    ) -> Publishers.Optional<ElementOfResult, Error> {
        return Publishers.Optional(
            result.tryMap { try $0.map { try nextPartialResult(initialResult, $0) } }
        )
    }

    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func tryRemoveDuplicates(
        by predicate: (Output, Output) throws -> Bool
    ) -> Publishers.Optional<Output, Error> {
        return Publishers.Optional(result.mapError { $0 })
    }

    public func replaceError(with output: Output) -> Publishers.Optional<Output, Never> {
        return Publishers.Optional(.success(result.unwrapOr(output)))
    }

    public func replaceEmpty(
        with output: Output
    ) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func retry(_ times: Int) -> Publishers.Optional<Output, Failure> {
        return self
    }

    public func retry() -> Publishers.Optional<Output, Failure> {
        return self
    }
}

extension Publishers.Optional where Failure == Never {

    public func setFailureType<Failure: Error>(
        to failureType: Failure.Type
    ) -> Publishers.Optional<Output, Failure> {
        return Publishers.Optional(result.success)
    }
}
