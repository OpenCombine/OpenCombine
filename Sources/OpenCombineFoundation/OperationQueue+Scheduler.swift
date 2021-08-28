//
//  OperationQueue+Scheduler.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2020.
//

import Foundation
import OpenCombine

extension OperationQueue {

    /// A namespace for disambiguation when both OpenCombine and Combine are imported.
    ///
    /// Foundation overlay for Combine extends `OperationQueue` with new methods and
    /// nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `OperationQueue.SchedulerTimeType`,
    /// because Swift is unable to understand which `SchedulerTimeType`
    /// you're referring to.
    ///
    /// So you have to write `OperationQueue.OCombine.SchedulerTimeType`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine: Scheduler {

        public let queue: OperationQueue

        public init(_ queue: OperationQueue) {
            self.queue = queue
        }

        /// The scheduler time type used by the operation queue.
        public struct SchedulerTimeType: Strideable, Codable, Hashable {

            /// The date represented by this type.
            public var date: Date

            /// Initializes a operation queue scheduler time with the given date.
            ///
            /// - Parameter date: The date to represent.
            public init(_ date: Date) {
                self.date = date
            }

            /// Returns the distance to another operation queue scheduler time.
            ///
            /// - Parameter other: Another operation queue time.
            /// - Returns: The time interval between this time and the provided time.
            public func distance(to other: SchedulerTimeType) -> Stride {
                let absoluteSelf = date.timeIntervalSinceReferenceDate
                let absoluteOther = other.date.timeIntervalSinceReferenceDate
                return Stride(absoluteSelf.distance(to: absoluteOther))
            }

            /// Returns an operation queue scheduler time calculated by advancing this
            /// instance’s time by the given interval.
            ///
            /// - Parameter n: A time interval to advance.
            /// - Returns: An operation queue time advanced by the given interval from
            ///   this instance’s time.
            public func advanced(by value: Stride) -> SchedulerTimeType {
                return SchedulerTimeType(date + value.magnitude)
            }

            /// The interval by which operation queue times advance.
            public struct Stride: SchedulerTimeIntervalConvertible,
                                  Comparable,
                                  SignedNumeric,
                                  ExpressibleByFloatLiteral,
                                  Codable {

                public typealias FloatLiteralType = TimeInterval

                public typealias IntegerLiteralType = TimeInterval

                public typealias Magnitude = TimeInterval

                /// The value of this time interval in seconds.
                public var magnitude: TimeInterval

                /// The value of this time interval in seconds.
                public var timeInterval: TimeInterval {
                    return magnitude
                }

                public init(integerLiteral value: TimeInterval) {
                    magnitude = value
                }

                public init(floatLiteral value: TimeInterval) {
                    magnitude = value
                }

                public init(_ timeInterval: TimeInterval) {
                    magnitude = timeInterval
                }

                public init?<Source: BinaryInteger>(exactly source: Source) {
                    guard let value = TimeInterval(exactly: source) else { return nil }
                    magnitude = value
                }

                public static func < (lhs: Stride, rhs: Stride) -> Bool {
                    return lhs.magnitude < rhs.magnitude
                }

                public static func * (lhs: Stride, rhs: Stride) -> Stride {
                    return Stride(lhs.magnitude * rhs.magnitude)
                }

                public static func + (lhs: Stride, rhs: Stride) -> Stride {
                    return Stride(lhs.magnitude + rhs.magnitude)
                }

                public static func - (lhs: Stride, rhs: Stride) -> Stride {
                    return Stride(lhs.magnitude - rhs.magnitude)
                }

                public static func *= (lhs: inout Stride, rhs: Stride) {
                    lhs.magnitude *= rhs.magnitude
                }

                public static func += (lhs: inout Stride, rhs: Stride) {
                    lhs.magnitude += rhs.magnitude
                }

                public static func -= (lhs: inout Stride, rhs: Stride) {
                    lhs.magnitude -= rhs.magnitude
                }

                public static func seconds(_ value: Int) -> Stride {
                    return Stride(TimeInterval(value))
                }

                public static func seconds(_ value: Double) -> Stride {
                    return Stride(TimeInterval(value))
                }

                public static func milliseconds(_ value: Int) -> Stride {
                    return Stride(TimeInterval(value) / 1_000)
                }

                public static func microseconds(_ value: Int) -> Stride {
                    return Stride(TimeInterval(value) / 1_000_000)
                }

                public static func nanoseconds(_ value: Int) -> Stride {
                    return Stride(TimeInterval(value) / 1_000_000_000)
                }
            }
        }

        /// Options that affect the operation of the operation queue scheduler.
        public struct SchedulerOptions {
        }

        private final class DelayReadyOperation: Operation, Cancellable {

            fileprivate final class CancellationContext: Cancellable {
                let lock = UnfairLock.allocate()
                weak var operation: DelayReadyOperation?

                deinit {
                    lock.deallocate()
                }

                func cancel() {
                    lock.lock()
                    guard let operation = self.operation else {
                        lock.unlock()
                        return
                    }
                    lock.unlock()
                    operation.action = nil
                    operation.queue = nil
                    operation.context = nil
                    operation.cancel()
                }
            }

            private static let readySchedulingQueue =
                DispatchQueue(label: "DelayReadyOperation")

            private let readyFromAfterLock = UnfairLock.allocate()
            private var action: (() -> Void)?
            private var readyFromAfter = false
            private var queue: OperationQueue?
            private let interval: SchedulerTimeType.Stride
            private var context: CancellationContext?

            init(action: @escaping () -> Void,
                 queue: OperationQueue?,
                 interval: SchedulerTimeType.Stride,
                 context: CancellationContext?) {
                self.action = action
                self.queue = queue
                self.interval = interval
                self.context = context
                super.init()
            }

            deinit {
                readyFromAfterLock.deallocate()
            }

            static func once(action: @escaping () -> Void,
                             after: SchedulerTimeType) -> DelayReadyOperation {
                let operation = DelayReadyOperation(action: action,
                                                    queue: nil,
                                                    interval: 0,
                                                    context: nil)
                operation.becomeReady(after: after.date.timeIntervalSinceNow,
                                      from: .now())
                return operation
            }

            static func repeating(
                action: @escaping () -> Void,
                after: SchedulerTimeType,
                queue: OperationQueue,
                interval: SchedulerTimeType.Stride,
                context: CancellationContext
            ) -> DelayReadyOperation {
                let operation = DelayReadyOperation(action: action,
                                                    queue: queue,
                                                    interval: interval,
                                                    context: context)
                operation.becomeReady(after: after.date.timeIntervalSinceNow,
                                      from: .now())
                return operation
            }

            override func main() {
                guard let action = self.action.take() else { return }
                action()

                guard let queue = self.queue.take(),
                      let context = self.context.take()
                else {
                    self.queue = nil
                    self.context = nil
                    return
                }

                context.lock.lock()
                if context.operation == nil {
                    context.lock.unlock()
                    return
                }
                let nextOperation = DelayReadyOperation(action: action,
                                                        queue: queue,
                                                        interval: interval,
                                                        context: context)
                context.operation = nextOperation
                queue.addOperation(nextOperation)
                context.lock.unlock()
                nextOperation.becomeReady(after: interval.timeInterval, from: .now())
            }

            private func becomeReady(after: TimeInterval, from time: DispatchTime) {
                DelayReadyOperation.readySchedulingQueue
                    .asyncAfter(deadline: time + after) { [weak self] in
                        self?.becomeReady()
                    }
            }

            private func becomeReady() {
// Smart key paths don't work with NSOperation in swift-corelibs-foundation prior to
// Swift 5.1 and on OS version prior to iOS 11.
// The string key paths work fine everywhere on Darwin platforms.
#if canImport(Darwin) || swift(<5.1)
                willChangeValue(forKey: "isReady")
#else
                willChangeValue(for: \.isReady)
#endif

                readyFromAfterLock.lock()
                readyFromAfter = true
                readyFromAfterLock.unlock()

// Smart key paths don't work with NSOperation in swift-corelibs-foundation prior to
// Swift 5.1 and on OS version prior to iOS 11.
// The string key paths work fine everywhere on Darwin platforms.
#if canImport(Darwin) || swift(<5.1)
                didChangeValue(forKey: "isReady")
#else
                didChangeValue(for: \.isReady)
#endif
            }

            override var isReady: Bool {
                guard super.isReady else { return false }
                readyFromAfterLock.lock()
                defer { readyFromAfterLock.unlock() }
                return readyFromAfter
            }
        }

        public func schedule(options: SchedulerOptions?,
                             _ action: @escaping () -> Void) {
            let op = BlockOperation(block: action)
            queue.addOperation(op)
        }

        public func schedule(after date: SchedulerTimeType,
                             tolerance: SchedulerTimeType.Stride,
                             options: SchedulerOptions?,
                             _ action: @escaping () -> Void) {
            let op = DelayReadyOperation.once(action: action, after: date)
            queue.addOperation(op)
        }

        public func schedule(after date: SchedulerTimeType,
                             interval: SchedulerTimeType.Stride,
                             tolerance: SchedulerTimeType.Stride,
                             options: SchedulerOptions?,
                             _ action: @escaping () -> Void) -> Cancellable {
            let context = DelayReadyOperation.CancellationContext()
            let op = DelayReadyOperation.repeating(action: action,
                                                   after: date,
                                                   queue: queue,
                                                   interval: interval,
                                                   context: context)
            context.operation = op
            queue.addOperation(op)
            return AnyCancellable(context)
        }

        public var now: SchedulerTimeType {
            return .init(Date())
        }

        public var minimumTolerance: SchedulerTimeType.Stride {
            return .init(0.0)
        }
    }

    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation overlay for Combine extends `OperationQueue` with new methods and
    /// nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `OperationQueue.main.schedule { doThings() }`,
    /// because Swift is unable to understand which `schedule` method
    /// you're referring to.
    ///
    /// So you have to write `OperationQueue.main.ocombine.schedule { doThings() }`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public var ocombine: OCombine {
        return OCombine(self)
    }
}

#if !canImport(Combine)
extension OperationQueue: OpenCombine.Scheduler {

    /// Options that affect the operation of the run loop scheduler.
    public typealias SchedulerOptions = OCombine.SchedulerOptions

    /// The scheduler time type used by the run loop.
    public typealias SchedulerTimeType = OCombine.SchedulerTimeType

    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        ocombine.schedule(options: options, action)
    }

    public func schedule(after date: SchedulerTimeType,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) {
        ocombine.schedule(after: date, tolerance: tolerance, options: options, action)
    }

    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) -> Cancellable {
        return ocombine.schedule(after: date,
                                 interval: interval,
                                 tolerance: tolerance,
                                 options: options,
                                 action)
    }

    public var now: SchedulerTimeType {
        return ocombine.now
    }

    public var minimumTolerance: SchedulerTimeType.Stride {
        return ocombine.minimumTolerance
    }
}
#endif
