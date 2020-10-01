//
//  Publishers.MapError.swift
//  
//
//  Created by Joseph Spadafora on 7/4/19.
//

extension Publishers {

    /// A publisher that converts any failure from the
    /// upstream publisher into a new error.
    public struct MapError<Upstream: Publisher, Failure: Error>: Publisher {

        /// The kind of values published by this publisher.
        public typealias Output = Upstream.Output

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// The closure that converts the upstream failure into a new error.
        public let transform: (Upstream.Failure) -> Failure

        public init(upstream: Upstream, _ map: @escaping (Upstream.Failure) -> Failure) {
            self.upstream = upstream
            self.transform = map
        }

        /// This function is called to attach the specified `Subscriber`
        /// to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, map: transform))
        }
    }
}

extension Publisher {

    /// Converts any failure from the upstream publisher into a new error.
    ///
    /// Use the `mapError(_:)` operator when you need to replace one error type with
    /// another, or where a downstream operator needs the error types of its inputs to
    /// match.
    ///
    /// The following example uses a `tryMap(_:)` operator to divide `1` by each element
    /// produced by a sequence publisher. When the publisher produces a `0`,
    /// the `tryMap(_:)` fails with a `DivisionByZeroError`. The `mapError(_:)` operator
    /// converts this into a `MyGenericError`.
    ///
    ///     struct DivisionByZeroError: Error {}
    ///     struct MyGenericError: Error { var wrappedError: Error }
    ///
    ///     func myDivide(_ dividend: Double, _ divisor: Double) throws -> Double {
    ///         guard divisor != 0 else { throw DivisionByZeroError() }
    ///         return dividend / divisor
    ///     }
    ///
    ///     let divisors: [Double] = [5, 4, 3, 2, 1, 0]
    ///     divisors.publisher
    ///         .tryMap { try myDivide(1, $0) }
    ///         .mapError { MyGenericError(wrappedError: $0) }
    ///         .sink(
    ///             receiveCompletion: { print ("completion: \($0)") ,
    ///             receiveValue: { print ("value: \($0)") }
    ///          )
    ///
    ///     // Prints:
    ///     //   value: 0.2
    ///     //   value: 0.25
    ///     //   value: 0.3333333333333333
    ///     //   value: 0.5
    ///     //   value: 1.0
    ///     //   completion: failure(MyGenericError(wrappedError: DivisionByZeroError()))"
    ///
    /// - Parameter transform: A closure that takes the upstream failure as a parameter
    ///   and returns a new error for the publisher to terminate with.
    /// - Returns: A publisher that replaces any upstream failure with a new error
    ///   produced by the `transform` closure.
    public func mapError<NewFailure: Error>(
        _ transform: @escaping (Failure) -> NewFailure
    ) -> Publishers.MapError<Self, NewFailure>
    {
        return Publishers.MapError(upstream: self, transform)
    }
}

extension Publishers.MapError {

    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Upstream.Output == Downstream.Input
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private let map: (Upstream.Failure) -> Downstream.Failure

        let combineIdentifier = CombineIdentifier()

        var description: String { return "MapError" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }

        init(downstream: Downstream,
             map: @escaping (Upstream.Failure) -> Downstream.Failure) {
            self.downstream = downstream
            self.map = map
        }

        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(map(error)))
            }
        }
    }
}
