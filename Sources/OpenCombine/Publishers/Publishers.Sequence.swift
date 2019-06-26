//
//  Publishers.Sequence.swift
//  
//
//  Created by Sergej Jaskiewicz on 19.06.2019.
//

extension Publishers {

    /// A publisher that publishes a given sequence of elements.
    ///
    /// When the publisher exhausts the elements in the sequence, the next request
    /// causes the publisher to finish.
    public struct Sequence<Elements: Swift.Sequence, Failure: Error>: Publisher {

        public typealias Output = Elements.Element

        /// The sequence of elements to publish.
        public let sequence: Elements

        /// Creates a publisher for a sequence of elements.
        ///
        /// - Parameter sequence: The sequence of elements to publish.
        public init(sequence: Elements) {
            self.sequence = sequence
        }

        public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
            where Failure == SubscriberType.Failure,
                  Elements.Element == SubscriberType.Input
        {
            if let inner = Inner(downstream: subscriber, sequence: sequence) {
                subscriber.receive(subscription: inner)
            } else {
                subscriber.receive(subscription: Subscriptions.empty)
                subscriber.receive(completion: .finished)
            }
        }
    }
}

extension Publishers.Sequence {

    private final class Inner<Downstream: Subscriber, Elements: Sequence, Failure>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable
        where Downstream.Input == Elements.Element,
              Downstream.Failure == Failure
    {
        typealias Iterator = Elements.Iterator
        typealias Element = Elements.Element

        private var _downstream: Downstream?
        private var _sequence: Elements?
        private var _iterator: Iterator?
        private var _nextValue: Element?

        init?(downstream: Downstream, sequence: Elements) {

            // Early exit if the sequence is empty
            var iterator = sequence.makeIterator()
            guard iterator.next() != nil else { return nil }

            _downstream = downstream
            _sequence = sequence
            _iterator = sequence.makeIterator()
            _nextValue = iterator.next()
        }

        var description: String {
            return _sequence.map(String.init(describing:)) ?? "Sequence"
        }

        var customMirror: Mirror {
            let children: CollectionOfOne<(label: String?, value: Any)> =
                    CollectionOfOne(("sequence", _sequence ?? [Element]()))
            return Mirror(self, children: children)
        }

        func request(_ demand: Subscribers.Demand) {

            guard let downstream = _downstream else { return }

            var demand = demand

            while demand > 0 {
                if let nextValue = _nextValue {
                    demand += downstream.receive(nextValue) - 1
                    _nextValue = _iterator?.next()
                } else {
                    _downstream?.receive(completion: .finished)
                    cancel()
                    break
                }
            }
        }

        func cancel() {
            _downstream = nil
            _iterator   = nil
            _sequence   = nil
        }
    }
}

extension Publishers.Sequence: Equatable where Elements: Equatable {}

extension Sequence {

    public func publisher() -> Publishers.Sequence<Self, Never> {
        return Publishers.Sequence(sequence: self)
    }
}
