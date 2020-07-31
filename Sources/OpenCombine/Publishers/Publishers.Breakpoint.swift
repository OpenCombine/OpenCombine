//
//  Publishers.Breakpoint.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

extension Publisher {

    /// Raises a debugger signal when a provided closure needs to stop the process in
    /// the debugger.
    ///
    /// When any of the provided closures returns `true`, this publisher raises
    /// the `SIGTRAP` signal to stop the process in the debugger.
    /// Otherwise, this publisher passes through values and completions as-is.
    ///
    /// - Parameters:
    ///   - receiveSubscription: A closure that executes when when the publisher receives
    ///     a subscription. Return `true` from this closure to raise `SIGTRAP`, or `false`
    ///     to continue.
    ///   - receiveOutput: A closure that executes when when the publisher receives
    ///     a value. Return `true` from this closure to raise `SIGTRAP`, or `false`
    ///     to continue.
    ///   - receiveCompletion: A closure that executes when when the publisher receives
    ///     a completion. Return `true` from this closure to raise `SIGTRAP`, or `false`
    ///     to continue.
    /// - Returns: A publisher that raises a debugger signal when one of the provided
    ///   closures returns `true`.
    public func breakpoint(
        receiveSubscription: ((Subscription) -> Bool)? = nil,
        receiveOutput: ((Output) -> Bool)? = nil,
        receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)? = nil
    ) -> Publishers.Breakpoint<Self> {
        return .init(upstream: self,
                     receiveSubscription: receiveSubscription,
                     receiveOutput: receiveOutput,
                     receiveCompletion: receiveCompletion)
    }

    /// Raises a debugger signal upon receiving a failure.
    ///
    /// When the upstream publisher fails with an error, this publisher raises
    /// the `SIGTRAP` signal, which stops the process in the debugger.
    /// Otherwise, this publisher passes through values and completions as-is.
    ///
    /// - Returns: A publisher that raises a debugger signal upon receiving a failure.
    public func breakpointOnError() -> Publishers.Breakpoint<Self> {
        return breakpoint { completion in
            switch completion {
            case .finished:
                return false
            case .failure:
                return true
            }
        }
    }
}

extension Publishers {

    /// A publisher that raises a debugger signal when a provided closure needs to stop
    /// the process in the debugger.
    ///
    /// When any of the provided closures returns `true`, this publisher raises
    /// the `SIGTRAP` signal to stop the process in the debugger.
    /// Otherwise, this publisher passes through values and completions as-is.
    public struct Breakpoint<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that executes when the publisher receives a subscription, and can
        /// raise a debugger signal by returning a `true` Boolean value.
        public let receiveSubscription: ((Subscription) -> Bool)?

        /// A closure that executes when the publisher receives output from the upstream
        /// publisher, and can raise a debugger signal by returning a `true` Boolean
        /// value.
        public let receiveOutput: ((Upstream.Output) -> Bool)?

        /// A closure that executes when the publisher receives completion, and can raise
        /// a debugger signal by returning a `true` Boolean value.
        public let receiveCompletion:
            ((Subscribers.Completion<Upstream.Failure>) -> Bool)?

        /// Creates a breakpoint publisher with the provided upstream publisher and
        /// breakpoint-raising closures.
        ///
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - receiveSubscription: A closure that executes when the publisher receives
        ///     a subscription, and can raise a debugger signal by returning a `true`
        ///     Boolean value.
        ///   - receiveOutput: A closure that executes when the publisher receives output
        ///     from the upstream publisher, and can raise a debugger signal by returning
        ///     a `true` Boolean value.
        ///   - receiveCompletion: A closure that executes when the publisher receives
        ///     completion, and can raise a debugger signal by returning a `true` Boolean
        ///     value.
        public init(
            upstream: Upstream,
            receiveSubscription: ((Subscription) -> Bool)? = nil,
            receiveOutput: ((Upstream.Output) -> Bool)? = nil,
            receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)? = nil
        ) {
            self.upstream = upstream
            self.receiveSubscription = receiveSubscription
            self.receiveOutput = receiveOutput
            self.receiveCompletion = receiveCompletion
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(self, downstream: subscriber))
        }
    }
}

extension Publishers.Breakpoint {
    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private let breakpoint: Publishers.Breakpoint<Upstream>

        let combineIdentifier = CombineIdentifier()

        init(_ breakpoint: Publishers.Breakpoint<Upstream>,
             downstream: Downstream) {
            self.downstream = downstream
            self.breakpoint = breakpoint
        }

        func receive(subscription: Subscription) {
            if breakpoint.receiveSubscription?(subscription) == true {
                __stopInDebugger()
            }
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            if breakpoint.receiveOutput?(input) == true {
                __stopInDebugger()
            }
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            if breakpoint.receiveCompletion?(completion) == true {
                __stopInDebugger()
            }
            downstream.receive(completion: completion)
        }

        var description: String { return "Breakpoint" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}
