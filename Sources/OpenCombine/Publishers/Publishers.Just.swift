//
//  Publishers.Just.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

extension Publishers {

    /// A publisher that emits an output to each subscriber just once, and then finishes.
    ///
    /// You can use a `Just` publisher to start a chain of publishers. A `Just` publisher is also useful when replacing
    /// a value with `Catch`.
    ///
    /// In contrast with `Publishers.Once`, a `Just` publisher cannot fail with an error.
    /// In contrast with `Publishers.Optional`, a `Just` publisher always produces a value.
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

        public func receive<S: Subscriber>(subscriber: S)
            where S.Input == Output, S.Failure == Never
        {
            subscriber.receive(subscription: Inner(value: output, downstream: subscriber))
        }
    }
}

private final class Inner<S: Subscriber>: Subscription,
                                          CustomStringConvertible,
                                          CustomReflectable
{
    private let _output: S.Input
    private var _downstream: S?

    init(value: S.Input, downstream: S) {
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

    var description: String { return "Just" }

    var customMirror: Mirror {
        return Mirror(self, unlabeledChildren: CollectionOfOne(_output))
    }
}

extension Publishers.Just: Equatable where Output: Equatable {}

extension Publishers.Just where Output: Comparable {

    public func min() -> Publishers.Just<Output> {
        return self
    }

    public func max() -> Publishers.Just<Output> {
        return self
    }
}

extension Publishers.Just where Output: Equatable {

    public func contains(_ output: Output) -> Publishers.Just<Bool> {
        return Publishers.Just(self.output == output)
    }

    public func removeDuplicates() -> Publishers.Just<Output> {
        return self
    }
}

extension Publishers.Just {

    public func allSatisfy(_ predicate: (Output) -> Bool) -> Publishers.Just<Bool> {
        return Publishers.Just(predicate(output))
    }

    public func tryAllSatisfy(
        _ predicate: (Output) throws -> Bool
    ) -> Publishers.Once<Bool, Error> {
        return Publishers.Once(Result { try predicate(output) })
    }

    public func contains(where predicate: (Output) -> Bool) -> Publishers.Just<Bool> {
        return Publishers.Just(predicate(output))
    }

    public func tryContains(
        where predicate: (Output) throws -> Bool
    ) -> Publishers.Once<Bool, Error> {
        return Publishers.Once(Result { try predicate(output) })
    }

    public func collect() -> Publishers.Just<[Output]> {
        return Publishers.Just([output])
    }

    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Publishers.Just<Output> {
        return self
    }

    public func max(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Publishers.Just<Output> {
        return self
    }

    public func count() -> Publishers.Just<Int> {
        return Publishers.Just(1)
    }

    public func first() -> Publishers.Just<Output> {
        return self
    }

    public func last() -> Publishers.Just<Output> {
        return self
    }

    public func ignoreOutput() -> Publishers.Empty<Output, Never> {
        return Publishers.Empty()
    }

    public func map<T>(_ transform: (Output) -> T) -> Publishers.Just<T> {
        return Publishers.Just(transform(output))
    }

    public func tryMap<T>(
        _ transform: (Output) throws -> T
    ) -> Publishers.Once<T, Error> {
        return Publishers.Once(Result { try transform(output) })
    }

    public func mapError<E: Error>(
        _ transform: (Never) -> E
    ) -> Publishers.Once<Output, E> {
        return Publishers.Once(output)
    }

    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Publishers.Just<Output> {
        return self
    }

    public func tryRemoveDuplicates(
        by predicate: (Output, Output) throws -> Bool
    ) -> Publishers.Once<Output, Error> {
        return Publishers
            .Once(Result { try _ = predicate(output, output); return output })
    }

    public func replaceError(with output: Output) -> Publishers.Just<Output> {
        return self
    }

    public func replaceEmpty(with output: Output) -> Publishers.Just<Output> {
        return self
    }

    public func retry(_ times: Int) -> Publishers.Just<Output> {
        return self
    }

    public func retry() -> Publishers.Just<Output> {
        return self
    }

    public func reduce<T>(
        _ initialResult: T,
        _ nextPartialResult: (T, Output) -> T
    ) -> Publishers.Once<T, Never> {
        return Publishers.Once(nextPartialResult(initialResult, output))
    }

    public func tryReduce<T>(
        _ initialResult: T,
        _ nextPartialResult: (T, Output) throws -> T
    ) -> Publishers.Once<T, Error> {
        return Publishers.Once(Result { try nextPartialResult(initialResult, output) })
    }

    public func scan<T>(
        _ initialResult: T,
        _ nextPartialResult: (T, Output) -> T
    ) -> Publishers.Once<T, Publishers.Just<Output>.Failure> {
        return Publishers.Once(nextPartialResult(initialResult, output))
    }

    public func tryScan<T>(
        _ initialResult: T,
        _ nextPartialResult: (T, Output) throws -> T
    ) -> Publishers.Once<T, Error> {
        return Publishers.Once(Result { try nextPartialResult(initialResult, output) })
    }

    public func setFailureType<E: Error>(
        to failureType: E.Type
    ) -> Publishers.Once<Output, E> {
        return Publishers.Once(output)
    }
}
