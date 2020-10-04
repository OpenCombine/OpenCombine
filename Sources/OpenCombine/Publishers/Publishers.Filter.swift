//
//  Publishers.Filter.swift
//  
//
//  Created by Joseph Spadafora on 7/3/19.
//

extension Publisher {

    /// Republishes all elements that match a provided closure.
    ///
    /// OpenCombine’s `filter(_:)` operator performs an operation similar to that of
    /// `filter(_:)` in the Swift Standard Library: it uses a closure to test each element
    /// to determine whether to republish the element to the downstream subscriber.
    ///
    /// The following example, uses a filter operation that receives an `Int` and only
    /// republishes a value if it’s even.
    ///
    ///     let numbers: [Int] = [1, 2, 3, 4, 5]
    ///     cancellable = numbers.publisher
    ///         .filter { $0 % 2 == 0 }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "2 4"
    ///
    /// - Parameter isIncluded: A closure that takes one element and returns
    ///   a Boolean value indicating whether to republish the element.
    /// - Returns: A publisher that republishes all elements that satisfy the closure.
    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.Filter<Self> {
        return Publishers.Filter(upstream: self, isIncluded: isIncluded)
    }

    /// Republishes all elements that match a provided error-throwing closure.
    ///
    /// Use `tryFilter(_:)` to filter elements evaluated in an error-throwing closure.
    /// If the `isIncluded` closure throws an error, the publisher fails with that error.
    ///
    /// In the example below, `tryFilter(_:)` checks to see if the divisor provided by
    /// the publisher is zero, and throws a `DivisionByZeroError` and then terminates
    /// the publisher with the thrown error:
    ///
    ///     struct DivisionByZeroError: Error {}
    ///
    ///     let numbers: [Int] = [1, 2, 3, 4, 0, 5]
    ///     cancellable = numbers.publisher
    ///         .tryFilter {
    ///             if $0 == 0 {
    ///                 throw DivisionByZeroError()
    ///             } else {
    ///                 return $0 % 2 == 0
    ///             }
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("\($0)") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///     // Prints: "2 4 failure(DivisionByZeroError())".
    ///
    /// - Parameter isIncluded: A closure that takes one element and returns a Boolean
    ///   value that indicated whether to republish the element or throws an error.
    /// - Returns: A publisher that republishes all elements that satisfy the closure.
    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Self> {
        return Publishers.TryFilter(upstream: self, isIncluded: isIncluded)
    }
}

extension Publishers.Filter {

    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.Filter<Upstream> {
        return .init(upstream: upstream) { self.isIncluded($0) && isIncluded($0) }
    }

    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
}

extension Publishers.TryFilter {

    public func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }

    public func tryFilter(
        _ isIncluded: @escaping (Output) throws -> Bool
    ) -> Publishers.TryFilter<Upstream> {
        return .init(upstream: upstream) { try self.isIncluded($0) && isIncluded($0) }
    }
}

extension Publishers {

    /// A publisher that republishes all elements that match a provided closure.
    public struct Filter<Upstream: Publisher>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that indicates whether to republish an element.
        public let isIncluded: (Upstream.Output) -> Bool

        public init(upstream: Upstream, isIncluded: @escaping (Output) -> Bool) {
            self.upstream = upstream
            self.isIncluded = isIncluded
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: isIncluded))
        }
    }

    /// A publisher that republishes all elements that match
    /// a provided error-throwing closure.
    public struct TryFilter<Upstream>: Publisher where Upstream: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A error-throwing closure that indicates whether to republish an element.
        public let isIncluded: (Upstream.Output) throws -> Bool

        public init(upstream: Upstream,
                    isIncluded: @escaping (Upstream.Output) throws -> Bool) {
            self.upstream = upstream
            self.isIncluded = isIncluded
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input,
                  Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: isIncluded))
        }
    }
}

extension Publishers.Filter {
    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private let filter: (Input) -> Bool

        let combineIdentifier = CombineIdentifier()

        init(downstream: Downstream, filter: @escaping (Input) -> Bool) {
            self.downstream = downstream
            self.filter = filter
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            if filter(input) {
                return downstream.receive(input)
            }
            return .max(1)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }

        var description: String { return "Filter" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

extension Publishers.TryFilter {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Upstream.Output) throws -> Bool>
        where Downstream.Input == Upstream.Output, Downstream.Failure == Error
    {
        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Upstream.Output?, Error> {
            do {
                return try filter(newValue) ? .continue(newValue) : .continue(nil)
            } catch {
                return .failure(error)
            }
        }

        override var description: String { return "TryFilter" }
    }
}
