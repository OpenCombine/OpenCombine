//
//  Result.Publisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Result {

    /// A namespace for disambiguation when both OpenCombine and Combine are imported.
    ///
    /// Combine extends `Result` with a nested type `Publisher`.
    /// If you import both OpenCombine and Combine (either explicitly or implicitly,
    /// e. g. when importing Foundation), you will not be able
    /// to write `Result<Int, Error>.Publisher`,
    /// because Swift is unable to understand which `Publisher` you're referring to.
    ///
    /// So you have to write `Result<Int, Error>.OCombine.Publisher`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine {

        fileprivate let result: Result

        fileprivate init(_ result: Result) {
            self.result = result
        }

        public var publisher: Publisher {
            return Publisher(result)
        }

        /// A publisher that publishes an output to each subscriber exactly once then
        /// finishes, or fails immediately without producing any elements.
        ///
        /// If `result` is `.success`, then `Once` waits until it receives a request for
        /// at least 1 value before sending the output. If `result` is `.failure`,
        /// then `Once` sends the failure immediately upon subscription.
        ///
        /// In contrast with `Just`, a `Once` publisher can terminate with an error
        /// instead of sending a value. In contrast with `Optional`, a `Once` publisher
        /// always sends one value (unless it terminates with an error).
        public struct Publisher: OpenCombine.Publisher {

            public typealias Output = Success

            /// The result to deliver to each subscriber.
            public let result: Result

            /// Creates a publisher that delivers the specified result.
            ///
            /// If the result is `.success`, the `Once` publisher sends the specified
            /// output to all subscribers and finishes normally. If the result is
            /// `.failure`, then the publisher fails immediately with the specified
            /// error.
            ///
            /// - Parameter result: The result to deliver to each subscriber.
            public init(_ result: Result) {
                self.result = result
            }

            /// Creates a publisher that sends the specified output to all subscribers and
            /// finishes normally.
            ///
            /// - Parameter output: The output to deliver to each subscriber.
            public init(_ output: Output) {
                self.init(.success(output))
            }

            /// Creates a publisher that immediately terminates upon subscription with
            /// the given failure.
            ///
            /// - Parameter failure: The failure to send when terminating.
            public init(_ failure: Failure) {
                self.init(.failure(failure))
            }

            public func receive<Downstream: Subscriber>(subscriber: Downstream)
                where Downstream.Input == Success, Downstream.Failure == Failure
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

    public var ocombine: OCombine {
        return OCombine(self)
    }

#if !canImport(Combine)
    /// A publisher that publishes an output to each subscriber exactly once then
    /// finishes, or fails immediately without producing any elements.
    ///
    /// If `result` is `.success`, then `Once` waits until it receives a request for
    /// at least 1 value before sending the output. If `result` is `.failure`, then `Once`
    /// sends the failure immediately upon subscription.
    ///
    /// In contrast with `Just`, a `Once` publisher can terminate with an error instead of
    /// sending a value. In contrast with `Optional`, a `Once` publisher always sends one
    /// value (unless it terminates with an error).
    public typealias Publisher = OCombine.Publisher

    public var publisher: Publisher {
        return Publisher(self)
    }
#endif
}

extension Result.OCombine {
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Success, Downstream.Failure == Failure
    {
        // NOTE: this class has been audited for thread safety.
        // Combine doesn't use any locking here.

        private var downstream: Downstream?
        private let output: Success

        init(value: Success, downstream: Downstream) {
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

        var description: String { return "Once" }

        var customMirror: Mirror {
            return Mirror(self, unlabeledChildren: CollectionOfOne(output))
        }

        var playgroundDescription: Any { return description }
    }
}

extension Result.OCombine.Publisher: Equatable
    where Output: Equatable, Failure: Equatable
{
}

extension Result.OCombine.Publisher where Output: Equatable {

    public func contains(_ output: Output) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(result.map { $0 == output })
    }

    public func removeDuplicates() -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }
}

extension Result.OCombine.Publisher where Output: Comparable {

    public func min() -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func max() -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }
}

extension Result.OCombine.Publisher {

    public func allSatisfy(
        _ predicate: (Output) -> Bool
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(result.map(predicate))
    }

    public func tryAllSatisfy(
        _ predicate: (Output) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(result.tryMap(predicate))
    }

    public func contains(
        where predicate: (Output) -> Bool
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(result.map(predicate))
    }

    public func tryContains(
        where predicate: (Output) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(result.tryMap(predicate))
    }

    public func collect() -> Result<[Output], Failure>.OCombine.Publisher {
        return .init(result.map { [$0] })
    }

    public func min(
        by areInIncreasingOrder: (Output, Output) -> Bool
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func tryMin(
        by areInIncreasingOrder: (Output, Output) throws -> Bool
    ) -> Result<Output, Error>.OCombine.Publisher {
        return .init(result.tryMap { _ = try areInIncreasingOrder($0, $0); return $0 })
    }

    public func max(
        by areInIncreasingOrder: (Output, Output
    ) -> Bool) -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func tryMax(
        by areInIncreasingOrder: (Output, Output) throws -> Bool
    ) -> Result<Output, Error>.OCombine.Publisher {
        return .init(result.tryMap { _ = try areInIncreasingOrder($0, $0); return $0 })
    }

    public func count() -> Result<Int, Failure>.OCombine.Publisher {
        return .init(result.map { _ in 1 })
    }

    public func first() -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func last() -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func ignoreOutput() -> Empty<Output, Failure> {
        return .init()
    }

    public func map<ElementOfResult>(
        _ transform: (Output) -> ElementOfResult
    ) -> Result<ElementOfResult, Failure>.OCombine.Publisher {
        return .init(result.map(transform))
    }

    public func tryMap<ElementOfResult>(
        _ transform: (Output) throws -> ElementOfResult
    ) -> Result<ElementOfResult, Error>.OCombine.Publisher {
        return .init(result.tryMap(transform))
    }

    public func mapError<TransformedFailure: Error>(
        _ transform: (Failure) -> TransformedFailure
    ) -> Result<Output, TransformedFailure>.OCombine.Publisher {
        return .init(result.mapError(transform))
    }

    public func removeDuplicates(
        by predicate: (Output, Output) -> Bool
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func tryRemoveDuplicates(
        by predicate: (Output, Output) throws -> Bool
    ) -> Result<Output, Error>.OCombine.Publisher {
        return .init(result.tryMap { _ = try predicate($0, $0); return $0 })
    }

    public func replaceError(
        with output: Output
    ) -> Result<Output, Never>.OCombine.Publisher {
        return .init(.success(result.unwrapOr(output)))
    }

    public func replaceEmpty(
        with output: Output
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func retry(_ times: Int) -> Result<Output, Failure>.OCombine.Publisher {
        return self
    }

    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) -> Accumulator
    ) -> Result<Accumulator, Failure>.OCombine.Publisher {
        return .init(result.map { nextPartialResult(initialResult, $0) })
    }

    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: (Accumulator, Output) throws -> Accumulator
    ) -> Result<Accumulator, Error>.OCombine.Publisher{
        return .init(result.tryMap { try nextPartialResult(initialResult, $0) })
    }

    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) -> ElementOfResult
    ) -> Result<ElementOfResult, Failure>.OCombine.Publisher {
        return .init(result.map { nextPartialResult(initialResult, $0) })
    }

    public func tryScan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult: (ElementOfResult, Output) throws -> ElementOfResult
    ) -> Result<ElementOfResult, Error>.OCombine.Publisher {
        return .init(result.tryMap { try nextPartialResult(initialResult, $0) })
    }
}

extension Result.OCombine.Publisher where Failure == Never {

    public func setFailureType<Failure: Error>(
        to failureType: Failure.Type
    ) -> Result<Output, Failure>.OCombine.Publisher {
        return .init(result.success)
    }
}
