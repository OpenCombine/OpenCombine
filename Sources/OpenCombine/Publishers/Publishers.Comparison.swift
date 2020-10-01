//
//  Publishers.Comparison.swift
//  OpenCombine
//
//  Created by Ilija Puaca on 22/7/19.
//

extension Publisher where Output: Comparable {

    /// Publishes the minimum value received from the upstream publisher, after it
    /// finishes.
    ///
    /// Use `min()` to find the minimum value in a stream of elements from
    /// an upstream publisher.
    ///
    /// In the example below, the `min()` operator emits a value when the publisher
    /// finishes, that value is the minimum of the values received from upstream, which
    /// is `-1`.
    ///
    ///     let numbers = [-1, 0, 10, 5]
    ///     numbers.publisher
    ///         .min()
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "-1"
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    ///
    /// - Returns: A publisher that publishes the minimum value received from the upstream
    ///   publisher, after the upstream publisher finishes.
    public func min() -> Publishers.Comparison<Self> {
        return max(by: >)
    }

    /// Publishes the maximum value received from the upstream publisher, after it
    /// finishes.
    ///
    /// Use `max()` to determine the maximum value in the stream of elements from
    /// an upstream publisher.
    ///
    /// In the example below, the `max()` operator emits a value when the publisher
    /// finishes, that value is the maximum of the values received from upstream, which
    /// is `10`.
    ///
    ///     let numbers = [0, 10, 5]
    ///     cancellable = numbers.publisher
    ///         .max()
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "10"
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    ///
    /// - Returns: A publisher that publishes the maximum value received from the upstream
    ///   publisher, after the upstream publisher finishes.
    public func max() -> Publishers.Comparison<Self> {
        return max(by: <)
    }
}

extension Publisher {

    /// Publishes the minimum value received from the upstream publisher, after it
    /// finishes.
    ///
    /// Use `min(by:)` to determine the minimum value in the stream of elements from
    /// an upstream publisher using a comparison operation you specify.
    ///
    /// This operator is useful when the value received from the upstream publisher isn’t
    /// `Comparable`.
    ///
    /// In the example below an array publishes enumeration elements representing playing
    /// card ranks. The `min(by:)` operator compares the current and next elements using
    /// the `rawValue` property of each enumeration value in the user supplied closure and
    /// prints the minimum value found after publishing all of the elements.
    ///
    ///     enum Rank: Int {
    ///         case ace = 1, two, three, four, five, six, seven, eight, nine,
    ///         ten, jack, queen, king
    ///     }
    ///
    ///     let cards: [Rank] = [.five, .queen, .ace, .eight, .king]
    ///     cancellable = cards.publisher
    ///         .min {
    ///             return  $0.rawValue < $1.rawValue
    ///         }
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "ace"
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    ///
    /// - Parameter areInIncreasingOrder: A closure that receives two elements and returns
    ///   `true` if they’re in increasing order.
    /// - Returns: A publisher that publishes the minimum value received from the upstream
    ///   publisher, after the upstream publisher finishes.
    public func min(
        by areInIncreasingOrder: @escaping (Output, Output) -> Bool
    ) -> Publishers.Comparison<Self> {
        return max(by: { areInIncreasingOrder($1, $0) })
    }

    /// Publishes the minimum value received from the upstream publisher, using
    /// the provided error-throwing closure to order the items.
    ///
    /// Use `tryMin(by:)` to determine the minimum value of elements received from
    /// the upstream publisher using an error-throwing closure you specify.
    ///
    /// In the example below, an array publishes elements. The `tryMin(by:)` operator
    /// executes the error-throwing closure that throws when the `first` element is an odd
    /// number, terminating the publisher.
    ///
    ///     struct IllegalValueError: Error {}
    ///
    ///     let numbers: [Int]  = [0, 10, 6, 13, 22, 22]
    ///     numbers.publisher
    ///         .tryMin { first, second -> Bool in
    ///             if (first % 2 != 0) {
    ///                 throw IllegalValueError()
    ///             }
    ///             return first < second
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") },
    ///             receiveValue: { print ("value: \($0)") }
    ///         )
    ///
    ///     // Prints: "completion: failure(IllegalValueError())"
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    ///
    /// - Parameter areInIncreasingOrder: A throwing closure that receives two elements
    ///   and returns `true` if they’re in increasing order. If this closure throws,
    ///   the publisher terminates with a `Subscribers.Completion.failure(_:)`.
    /// - Returns: A publisher that publishes the minimum value received from the upstream
    ///   publisher, after the upstream publisher finishes.
    public func tryMin(
        by areInIncreasingOrder: @escaping (Output, Output) throws -> Bool
    ) -> Publishers.TryComparison<Self> {
        return tryMax(by: { try areInIncreasingOrder($1, $0) })
    }

    /// Publishes the maximum value received from the upstream publisher, using
    /// the provided ordering closure.
    ///
    /// Use `max(by:)` to determine the maximum value of elements received from
    /// the upstream publisher based on an ordering closure you specify.
    ///
    /// In the example below, an array publishes enumeration elements representing playing
    /// card ranks. The `max(by:)` operator compares the current and next elements using
    /// the `rawValue` property of each enumeration value in the user supplied closure and
    /// prints the maximum value found after publishing all of the elements.
    ///
    ///     enum Rank: Int {
    ///         case ace = 1, two, three, four, five, six, seven, eight, nine,
    ///         ten, jack, queen, king
    ///     }
    ///
    ///     let cards: [Rank] = [.five, .queen, .ace, .eight, .jack]
    ///     cancellable = cards.publisher
    ///         .max {
    ///             return  $0.rawValue > $1.rawValue
    ///         }
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "queen"
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    ///
    /// - Parameter areInIncreasingOrder: A closure that receives two elements and returns
    ///   `true` if they’re in increasing order.
    /// - Returns: A publisher that publishes the maximum value received from the upstream
    ///   publisher, after the upstream publisher finishes.
    public func max(
        by areInIncreasingOrder: @escaping (Output, Output) -> Bool
    ) -> Publishers.Comparison<Self> {
        return .init(upstream: self, areInIncreasingOrder: areInIncreasingOrder)
    }

    /// Publishes the maximum value received from the upstream publisher, using
    /// the provided error-throwing closure to order the items.
    ///
    /// Use `tryMax(by:)` to determine the maximum value of elements received from
    /// the upstream publisher using an error-throwing closure you specify.
    ///
    /// In the example below, an array publishes elements. The `tryMax(by:)` operator
    /// executes the error-throwing closure that throws when the `first` element is
    /// an odd number, terminating the publisher.
    ///
    ///     struct IllegalValueError: Error {}
    ///
    ///     let numbers: [Int]  = [0, 10, 6, 13, 22, 22]
    ///     cancellable = numbers.publisher
    ///         .tryMax { first, second -> Bool in
    ///             if (first % 2 != 0) {
    ///                 throw IllegalValueError()
    ///             }
    ///             return first > second
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") },
    ///             receiveValue: { print ("value: \($0)") }
    ///         )
    ///
    ///     // Prints: completion: failure(IllegalValueError())
    ///
    /// After this publisher receives a request for more than 0 items, it requests
    /// unlimited items from its upstream publisher.
    ///
    /// - Parameter areInIncreasingOrder: A throwing closure that receives two elements
    ///   and returns `true` if they’re in increasing order. If this closure throws,
    ///   the publisher terminates with a ``Subscribers/Completion/failure(_:)``.
    ///
    /// - Returns: A publisher that publishes the maximum value received from the upstream
    ///   publisher, after the upstream publisher finishes.
    public func tryMax(
        by areInIncreasingOrder:  @escaping (Output, Output) throws -> Bool
    ) -> Publishers.TryComparison<Self> {
        return .init(upstream: self, areInIncreasingOrder: areInIncreasingOrder)
    }
}

extension Publishers {

    /// A publisher that republishes items from another publisher only if each new item is
    /// in increasing order from the previously-published item.
    public struct Comparison<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that receives two elements and returns `true` if they are in
        /// increasing order.
        public let areInIncreasingOrder: (Upstream.Output, Upstream.Output) -> Bool

        public init(
            upstream: Upstream,
            areInIncreasingOrder: @escaping (Upstream.Output, Upstream.Output) -> Bool
        ) {
            self.upstream = upstream
            self.areInIncreasingOrder = areInIncreasingOrder
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            let inner = Inner(downstream: subscriber,
                              areInIncreasingOrder: areInIncreasingOrder)
            upstream.subscribe(inner)
        }
    }

    /// A publisher that republishes items from another publisher only if each new item is
    /// in increasing order from the previously-published item, and fails if the ordering
    /// logic throws an error.
    public struct TryComparison<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// A closure that receives two elements and returns `true` if they are in
        /// increasing order.
        public let areInIncreasingOrder: (Upstream.Output, Upstream.Output) throws -> Bool

        public init(
            upstream: Upstream,
            areInIncreasingOrder:
                @escaping (Upstream.Output, Upstream.Output) throws -> Bool
        ) {
            self.upstream = upstream
            self.areInIncreasingOrder = areInIncreasingOrder
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input, Downstream.Failure == Error
        {
            let inner = Inner(downstream: subscriber,
                              areInIncreasingOrder: areInIncreasingOrder)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Comparison {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output, Upstream.Output) -> Bool>
    where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        fileprivate init(
            downstream: Downstream,
            areInIncreasingOrder: @escaping (Upstream.Output, Upstream.Output) -> Bool
        ) {
            super.init(downstream: downstream, initial: nil, reduce: areInIncreasingOrder)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            if let result = self.result {
                if reduce(result, newValue) {
                    self.result = newValue
                }
            } else {
                self.result = newValue
            }
            return .continue
        }

        override var description: String {
            return "Comparison"
        }
    }
}

extension Publishers.TryComparison {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output, Upstream.Output) throws -> Bool>
    where Downstream.Input == Upstream.Output, Downstream.Failure == Error
    {
        fileprivate init(
            downstream: Downstream,
            areInIncreasingOrder:
                @escaping (Upstream.Output, Upstream.Output) throws -> Bool
        ) {
            super.init(downstream: downstream, initial: nil, reduce: areInIncreasingOrder)
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            do {
                if let result = self.result {
                    if try reduce(result, newValue) {
                        self.result = newValue
                    }
                } else {
                    self.result = newValue
                }
                return .continue
            } catch {
                return .failure(error)
            }
        }

        override var description: String {
            return "TryComparison"
        }
    }
}
