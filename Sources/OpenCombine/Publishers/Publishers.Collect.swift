//
//  Publishers.Collect.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.10.2019.
//

extension Publisher {

    /// Collects all received elements, and emits a single array of the collection when
    /// the upstream publisher finishes.
    ///
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    /// This publisher requests an unlimited number of elements from the upstream
    /// publisher. It only sends the collected array to its downstream after a request
    /// whose demand is greater than 0 items.
    /// Note: This publisher uses an unbounded amount of memory to store the received
    /// values.
    ///
    /// - Returns: A publisher that collects all received items and returns them as
    ///   an array upon completion.
    public func collect() -> Publishers.Collect<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that buffers items.
    public struct Collect<Upstream: Publisher>: Publisher {

        public typealias Output = [Upstream.Output]

        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Downstream.Input == [Upstream.Output]
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
    }
}

extension Publishers.Collect: Equatable where Upstream: Equatable {}

extension Publishers.Collect {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         [Upstream.Output],
                         Upstream.Failure,
                         Void>
        where Downstream.Input == [Upstream.Output],
              Downstream.Failure == Upstream.Failure
    {
        fileprivate init(downstream: Downstream) {
            super.init(downstream: downstream, initial: [], reduce: ())
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            result!.append(newValue)
            return .continue
        }

        override var description: String {
            return "Collect"
        }

        override var customMirror: Mirror {
            let children: CollectionOfOne<Mirror.Child> = .init(("count", result!.count))
            return Mirror(self, children: children)
        }
    }
}
