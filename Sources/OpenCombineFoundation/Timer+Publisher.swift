//
//  Timer+Publisher.swift
//
//
//  Created by Sergej Jaskiewicz on 23.06.2020.
//

import Foundation
import OpenCombine

extension Foundation.Timer {

    /// Returns a publisher that repeatedly emits the current date on the given interval.
    ///
    /// - Parameters:
    ///   - interval: The time interval on which to publish events. For example,
    ///     a value of `0.5` publishes an event approximately every half-second.
    ///   - tolerance: The allowed timing variance when emitting events.
    ///     Defaults to `nil`, which allows any variance.
    ///   - runLoop: The run loop on which the timer runs.
    ///   - mode: The run loop mode in which to run the timer.
    ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
    /// - Returns: A publisher that repeatedly emits the current date on the given
    ///   interval.
    public static func publish(
        every interval: TimeInterval,
        tolerance _: TimeInterval? = nil,
        on runLoop: RunLoop,
        in mode: RunLoop.Mode,
        options: RunLoop.OCombine.SchedulerOptions? = nil
    ) -> OCombine.TimerPublisher {
        // A bug in Combine: tolerance is ignored.
        return .init(interval: interval, runLoop: runLoop, mode: mode, options: options)
    }

    /// A namespace for disambiguation when both OpenCombine and Combine are imported.
    ///
    /// Foundation overlay for Combine extends `Timer` with new methods and nested
    /// types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `Timer.TimerPublisher`,
    /// because Swift is unable to understand which `TimerPublisher`
    /// you're referring to.
    ///
    /// So you have to write `Timer.OCombine.TimerPublisher`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public enum OCombine {

        /// A publisher that repeatedly emits the current date on a given interval.
        public final class TimerPublisher: ConnectablePublisher {
            public typealias Output = Date
            public typealias Failure = Never

            public let interval: TimeInterval
            public let tolerance: TimeInterval?
            public let runLoop: RunLoop
            public let mode: RunLoop.Mode
            public let options: RunLoop.OCombine.SchedulerOptions?

            private var sides = [CombineIdentifier : Side]()

            private let lock = UnfairLock.allocate()

            /// Creates a publisher that repeatedly emits the current date
            /// on the given interval.
            ///
            /// - Parameters:
            ///   - interval: The interval on which to publish events.
            ///   - tolerance: The allowed timing variance when emitting events.
            ///     Defaults to `nil`, which allows any variance.
            ///   - runLoop: The run loop on which the timer runs.
            ///   - mode: The run loop mode in which to run the timer.
            ///   - options: Scheduler options passed to the timer. Defaults to `nil`.
            public init(
                interval: TimeInterval,
                tolerance: TimeInterval? = nil,
                runLoop: RunLoop,
                mode: RunLoop.Mode,
                options: RunLoop.OCombine.SchedulerOptions? = nil
            ) {
                self.interval = interval
                self.tolerance = tolerance
                self.runLoop = runLoop
                self.mode = mode
                self.options = options
            }

            deinit {
                lock.deallocate()
            }

            public func receive<Downstream: Subscriber>(subscriber: Downstream)
                where Failure == Downstream.Failure, Output == Downstream.Input
            {
                let inner = Inner(parent: self, downstream: subscriber)
                lock.lock()
                sides[inner.combineIdentifier] = Side(inner)
                lock.unlock()
                subscriber.receive(subscription: inner)
            }

            public func connect() -> Cancellable {
                let timer = Timer(timeInterval: interval, repeats: true, block: fire)
                timer.tolerance = tolerance ?? 0
                runLoop.add(timer, forMode: mode)
                return CancellableTimer(timer: timer, publisher: self)
            }

            // MARK: Private

            private func fire(_ timer: Timer) {
                lock.lock()
                let sides = self.sides
                lock.unlock()
                let now = Date()
                for side in sides.values {
                    side.send(now)
                }
            }

            private func disconnectAll() {
                lock.lock()
                sides = [:]
                lock.unlock()
            }

            private func disconnect(_ innerID: CombineIdentifier) {
                lock.lock()
                sides[innerID] = nil
                lock.unlock()
            }

            private struct Side {
                let send: (Date) -> Void

                init<Downstream: Subscriber>(_ inner: Inner<Downstream>)
                    where Downstream.Input == Date, Downstream.Failure == Never
                {
                    send = inner.send
                }
            }

            private struct CancellableTimer: Cancellable {
                let timer: Timer
                let publisher: TimerPublisher

                func cancel() {
                    publisher.disconnectAll()
                    timer.invalidate()
                }
            }

            private final class Inner<Downstream: Subscriber>: Subscription
                where Downstream.Input == Date, Downstream.Failure == Never
            {
                private var downstream: Downstream?

                private var pending = Subscribers.Demand.none

                private weak var parent: TimerPublisher?

                private let lock = UnfairLock.allocate()

                init(parent: TimerPublisher, downstream: Downstream) {
                    self.parent = parent
                    self.downstream = downstream
                }

                deinit {
                    lock.deallocate()
                }

                func send(_ date: Date) {
                    lock.lock()
                    guard let downstream = self.downstream, pending != .none else {
                        lock.unlock()
                        return
                    }
                    pending -= 1
                    lock.unlock()
                    let newDemand = downstream.receive(date)
                    if newDemand == .none {
                        return
                    }
                    lock.lock()
                    pending += newDemand
                    lock.unlock()
                }

                func request(_ demand: Subscribers.Demand) {
                    lock.lock()
                    if downstream == nil {
                        lock.unlock()
                        return
                    }
                    pending += demand
                    lock.unlock()
                }

                func cancel() {
                    lock.lock()
                    if downstream.take() == nil {
                        lock.unlock()
                        return
                    }
                    lock.unlock()
                    parent?.disconnect(combineIdentifier)
                }
            }
        }
    }
}

#if !canImport(Combine)
extension Foundation.Timer {

    /// A publisher that repeatedly emits the current date on a given interval.
    public typealias TimerPublisher = OCombine.TimerPublisher
}
#endif
