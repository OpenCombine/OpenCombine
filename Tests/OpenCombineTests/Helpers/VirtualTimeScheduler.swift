//
//  VirtualTimeScheduler.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 14/09/2019.
//

import OpenCombine

open class VirtualTimeScheduler: Scheduler {

    public struct SchedulerTimeType: Strideable {

        public var date: Int { stride.magnitude }
        private let stride: Stride

        public init(date: Int) {
            self.stride = .init(date)
        }

        /// The increment by which the immediate scheduler counts time.
        public struct Stride: ExpressibleByFloatLiteral,
                               Comparable,
                               SignedNumeric,
                               Codable,
                               SchedulerTimeIntervalConvertible {

            public typealias FloatLiteralType = Double

            public typealias IntegerLiteralType = Int

            public typealias Magnitude = Int

            public var magnitude: Int

            @inlinable
            public init(_ value: Int) {
                magnitude = value
            }

            @inlinable
            public init(integerLiteral value: Int) {
                self.init(value)
            }

            @inlinable
            public init(floatLiteral value: Double) {
                self.init(Int(value))
            }

            @inlinable
            public init?<BinaryIntegerType: BinaryInteger>(
                exactly source: BinaryIntegerType
            ) {
                guard let magnitude = Int(exactly: source) else {
                    return nil
                }
                self.init(magnitude)
            }

            @inlinable
            public static func < (lhs: Stride, rhs: Stride) -> Bool {
                return lhs.magnitude < rhs.magnitude
            }

            @inlinable
            public static func * (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(lhs.magnitude * rhs.magnitude)
            }

            @inlinable
            public static func + (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(lhs.magnitude + rhs.magnitude)
            }

            @inlinable
            public static func - (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(lhs.magnitude - rhs.magnitude)
            }

            @inlinable
            public static func -= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude -= rhs.magnitude
            }

            public static func *= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude *= rhs.magnitude
            }

            public static func += (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude += rhs.magnitude
            }

            public static func seconds(_ val: Int) -> Stride { .init(val) }

            public static func seconds(_ val: Double) -> Stride { .init(Int(val)) }

            public static func milliseconds(_: Int) -> Stride { return 0 }

            public static func microseconds(_: Int) -> Stride { return 0 }

            public static func nanoseconds(_: Int) -> Stride { return 0 }
        }

        public func distance(to other: VirtualTimeScheduler.SchedulerTimeType)
            -> VirtualTimeScheduler.SchedulerTimeType.Stride {
            let diff = other.date - self.date
            return .init(diff)
        }

        public func advanced(by n: VirtualTimeScheduler.SchedulerTimeType.Stride)
            -> VirtualTimeScheduler.SchedulerTimeType {
            return .init(date: self.date + n.magnitude)
        }
    }
    public struct SchedulerOptions {
    }

    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        let item = QueueItem(date: now, action: action)
        add(item: item)
    }

    public var now: SchedulerTimeType { _now }

    public var minimumTolerance: SchedulerTimeType.Stride { return 0 }

    public func schedule(after date: SchedulerTimeType,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) {
        let item = QueueItem(date: date, action: action)
        add(item: item)
    }

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) -> Cancellable {
        let item = QueueItem(date: date, action: action)
        add(item: item)
        return AnyCancellable(item)
    }

    public func flush() {
        let queue = self.queue
        self.queue.removeAll()
        for item in queue {
            print("\(item)")
            _now = item.date
            item.action?()
        }
        if !self.queue.isEmpty {
            flush()
        }
    }

    private var _now: SchedulerTimeType = .init(date: 0)
    private var queue: [QueueItem] = []

    private func add(item: QueueItem) {
        let index = queue.firstIndex(where: { $0.date > item.date })
        queue.insert(item, at: index ?? queue.count)
    }
}

extension VirtualTimeScheduler {
    typealias Action = () -> Void

    private class QueueItem: Cancellable, CustomStringConvertible {
        let date: SchedulerTimeType
        private(set) var action: Action?

        init(date: SchedulerTimeType, action: @escaping Action) {
            self.date = date
            self.action = action
        }

        func cancel() {
            action = nil
        }

        var description: String { "\(date)" }
    }
}
