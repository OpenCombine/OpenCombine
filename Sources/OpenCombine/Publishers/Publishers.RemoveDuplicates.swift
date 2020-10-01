//
//  Publishers.RemoveDuplicates.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.10.2019.
//

extension Publisher where Output: Equatable {

    /// Publishes only elements that don’t match the previous element.
    ///
    /// Use `removeDuplicates()` to remove repeating elements from an upstream publisher.
    /// This operator has a two-element memory: the operator uses the current and
    /// previously published elements as the basis for its comparison.
    ///
    /// In the example below, `removeDuplicates()` triggers on the doubled, tripled, and
    /// quadrupled occurrences of `1`, `3`, and `4` respectively. Because the two-element
    /// memory considers only the current element and the previous element, the operator
    /// prints the final `0` in the example data since its immediate predecessor is `4`.
    ///
    ///     let numbers = [0, 1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 0]
    ///     cancellable = numbers.publisher
    ///         .removeDuplicates()
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1 2 3 4 0"
    ///
    /// - Returns: A publisher that consumes — rather than publishes — duplicate elements.
    public func removeDuplicates() -> Publishers.RemoveDuplicates<Self> {
        return removeDuplicates(by: ==)
    }
}

extension Publisher {

    /// Publishes only elements that don’t match the previous element, as evaluated by
    /// a provided closure.
    ///
    /// Use `removeDuplicates(by:)` to remove repeating elements from an upstream
    /// publisher based upon the evaluation of the current and previously published
    /// elements using a closure you provide.
    ///
    /// Use the `removeDuplicates(by:)` operator when comparing types that don’t
    /// themselves implement `Equatable`, or if you need to compare values differently
    /// than the type’s `Equatable` implementation.
    ///
    /// In the example below, the `removeDuplicates(by:)` functionality triggers when
    /// the `x` property of the current and previous elements are equal, otherwise
    /// the operator publishes the current `Point` to the downstream subscriber:
    ///
    ///     struct Point {
    ///         let x: Int
    ///         let y: Int
    ///     }
    ///
    ///     let points = [Point(x: 0, y: 0), Point(x: 0, y: 1),
    ///                   Point(x: 1, y: 1), Point(x: 2, y: 1)]
    ///     cancellable = points.publisher
    ///         .removeDuplicates { prev, current in
    ///             // Considers points to be duplicate if the x coordinate
    ///             // is equal, and ignores the y coordinate
    ///             prev.x == current.x
    ///         }
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: Point(x: 0, y: 0) Point(x: 1, y: 1) Point(x: 2, y: 1)
    ///
    /// - Parameter predicate: A closure to evaluate whether two elements are equivalent,
    ///   for purposes of filtering. Return `true` from this closure to indicate that
    ///   the second element is a duplicate of the first.
    /// - Returns: A publisher that consumes — rather than publishes — duplicate elements.
    public func removeDuplicates(
        by predicate: @escaping (Output, Output) -> Bool
    ) -> Publishers.RemoveDuplicates<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes only elements that don’t match the previous element, as evaluated by
    /// a provided error-throwing closure.
    ///
    /// Use `tryRemoveDuplicates(by:)` to remove repeating elements from an upstream
    /// publisher based upon the evaluation of elements using an error-throwing closure
    /// you provide. If your closure throws an error, the publisher terminates with
    /// the error.
    ///
    /// In the example below, the closure provided to `tryRemoveDuplicates(by:)` returns
    /// `true` when two consecutive elements are equal, thereby filtering out `0`,
    /// `1`, `2`, and `3`. However, the closure throws an error when it encounters `4`.
    /// The publisher then terminates with this error.
    ///
    ///     struct BadValuesError: Error {}
    ///     let numbers = [0, 0, 0, 0, 1, 2, 2, 3, 3, 3, 4, 4, 4, 4]
    ///     cancellable = numbers.publisher
    ///         .tryRemoveDuplicates { first, second -> Bool in
    ///             if (first == 4 && second == 4) {
    ///                 throw BadValuesError()
    ///             }
    ///             return first == second
    ///         }
    ///         .sink(
    ///             receiveCompletion: { print ("\($0)") },
    ///             receiveValue: { print ("\($0)", terminator: " ") }
    ///          )
    ///
    ///      // Prints: "0 1 2 3 4 failure(BadValuesError()"
    ///
    /// - Parameter predicate: A closure to evaluate whether two elements are equivalent,
    ///   for purposes of filtering. Return `true` from this closure to indicate that
    ///   the second element is a duplicate of the first. If this closure throws an error,
    ///   the publisher terminates with the thrown error.
    /// - Returns: A publisher that consumes — rather than publishes — duplicate elements.
    public func tryRemoveDuplicates(
        by predicate: @escaping (Output, Output) throws -> Bool
    ) -> Publishers.TryRemoveDuplicates<Self> {
        return .init(upstream: self, predicate: predicate)
    }
}

extension Publishers {

    /// A publisher that publishes only elements that don’t match the previous element.
    public struct RemoveDuplicates<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The predicate closure used to evaluate whether two elements are duplicates.
        public let predicate: (Output, Output) -> Bool

        /// Creates a publisher that publishes only elements that don’t match the previous
        /// element, as evaluated by a provided closure.
        ///
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        /// - Parameter predicate: A closure to evaluate whether two elements are
        ///   equivalent, for purposes of filtering. Return `true` from this closure
        ///   to indicate that the second element is a duplicate of the first.
        public init(upstream: Upstream, predicate: @escaping (Output, Output) -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: predicate))
        }
    }

    /// A publisher that publishes only elements that don’t match the previous element,
    /// as evaluated by a provided error-throwing closure.
    public struct TryRemoveDuplicates<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Error

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// An error-throwing closure to evaluate whether two elements are equivalent,
        /// for purposes of filtering.
        public let predicate: (Output, Output) throws -> Bool

        /// Creates a publisher that publishes only elements that don’t match the previous
        /// element, as evaluated by a provided error-throwing closure.
        ///
        /// - Parameter upstream: The publisher from which this publisher receives
        ///   elements.
        /// - Parameter predicate: An error-throwing closure to evaluate whether two
        ///   elements are equivalent, for purposes of filtering. Return `true` from this
        ///   closure to indicate that the second element is a duplicate of the first.
        ///   If this closure throws an error, the publisher terminates
        ///   with the thrown error.
        public init(upstream: Upstream,
                    predicate: @escaping (Output, Output) throws -> Bool) {
            self.upstream = upstream
            self.predicate = predicate
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Output == Downstream.Input, Downstream.Failure == Error
        {
            upstream.subscribe(Inner(downstream: subscriber, filter: predicate))
        }
    }
}

extension Publishers.RemoveDuplicates {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Output, Output) -> Bool>
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        private var last: Upstream.Output?

        override func receive(
            newValue: Input
        ) -> PartialCompletion<Upstream.Output?, Downstream.Failure> {
            let last = self.last
            self.last = newValue
            return last.map {
                filter($0, newValue) ? .continue(nil) : .continue(newValue)
            } ?? .continue(newValue)
        }

        override var description: String { return "RemoveDuplicates" }

        override var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("last", last as Any)
            ]
            return Mirror(self, children: children)
        }
    }
}

extension Publishers.TryRemoveDuplicates {
    private final class Inner<Downstream: Subscriber>
        : FilterProducer<Downstream,
                         Upstream.Output,
                         Upstream.Output,
                         Upstream.Failure,
                         (Output, Output) throws -> Bool>
        where Downstream.Input == Upstream.Output, Downstream.Failure == Error
    {
        private var last: Upstream.Output?

        override func receive(
            newValue: Input
        ) -> PartialCompletion<Upstream.Output?, Downstream.Failure> {
            let last = self.last
            self.last = newValue
            return last.map {
                do {
                    return try filter($0, newValue)
                        ? .continue(nil)
                        : .continue(newValue)
                } catch {
                    return .failure(error)
                }
            } ?? .continue(newValue)
        }

        override var description: String { return "TryRemoveDuplicates" }

        override var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("downstream", downstream),
                ("last", last as Any)
            ]
            return Mirror(self, children: children)
        }
    }
}
