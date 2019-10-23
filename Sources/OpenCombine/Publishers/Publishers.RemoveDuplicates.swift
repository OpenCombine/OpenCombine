//
//  Publishers.RemoveDuplicates.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.10.2019.
//

extension Publisher where Output: Equatable {

    /// Publishes only elements that don’t match the previous element.
    ///
    /// - Returns: A publisher that consumes — rather than publishes — duplicate elements.
    public func removeDuplicates() -> Publishers.RemoveDuplicates<Self> {
        return removeDuplicates(by: ==)
    }
}

extension Publisher {

    /// Publishes only elements that don’t match the previous element, as evaluated by
    /// a provided closure.
    ///
    /// - Parameter predicate: A closure to evaluate whether two elements are equivalent,
    ///   for purposes of filtering. Return `true` from this closure to indicate that
    ///   the second element is a duplicate of the first.
    public func removeDuplicates(
        by predicate: @escaping (Output, Output) -> Bool
    ) -> Publishers.RemoveDuplicates<Self> {
        return .init(upstream: self, predicate: predicate)
    }

    /// Publishes only elements that don’t match the previous element, as evaluated by
    /// a provided error-throwing closure.
    ///
    /// - Parameter predicate: A closure to evaluate whether two elements are equivalent,
    ///   for purposes of filtering. Return `true` from this closure to indicate that
    ///   the second element is a duplicate of the first. If this closure throws an error,
    ///   the publisher terminates with the thrown error.
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

        /// A closure to evaluate whether two elements are equivalent,
        /// for purposes of filtering.
        public let predicate: (Output, Output) -> Bool

        /// Creates a publisher that publishes only elements that don’t match the previou
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
    public struct TryRemoveDuplicates<Upstream: Publisher>: Publisher{

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
        // NOTE: This class has been audited for thread-safety

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
        // NOTE: This class has been audited for thread-safety

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
