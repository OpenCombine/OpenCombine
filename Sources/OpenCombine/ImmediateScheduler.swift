//
//  ImmediateScheduler.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A scheduler for performing synchronous actions.
///
/// You can use this scheduler for immediate actions. If you attempt to schedule
/// actions after a specific date, the scheduler produces a fatal error.
public struct ImmediateScheduler: Scheduler {

    /// The time type used by the immediate scheduler.
    public struct SchedulerTimeType: Strideable {

        fileprivate init() {}

        /// Returns the distance to another immediate scheduler time; this distance is
        /// always `0` in the context of an immediate scheduler.
        ///
        /// - Parameter other: The other scheduler time.
        /// - Returns: `0`, as a `Stride`.
        public func distance(to other: SchedulerTimeType) -> Stride { return 0 }

        /// Advances the time by the specified amount; this is meaningless in the context
        /// of an immediate scheduler.
        ///
        /// - Parameter n: The amount to advance by. The `ImmediateScheduler` ignores this
        ///   value.
        /// - Returns: An empty `SchedulerTimeType`.
        public func advanced(by _: Stride) -> SchedulerTimeType {
            return SchedulerTimeType()
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

            public static func seconds(_: Int) -> Stride { return 0 }

            public static func seconds(_: Double) -> Stride { return 0 }

            public static func milliseconds(_: Int) -> Stride { return 0 }

            public static func microseconds(_: Int) -> Stride { return 0 }

            public static func nanoseconds(_: Int) -> Stride { return 0 }
        }
    }

    public typealias SchedulerOptions = Never

    /// The shared instance of the immediate scheduler.
    ///
    /// You cannot create instances of the immediate scheduler yourself. Use only
    /// the shared instance.
    public static let shared = ImmediateScheduler()

    @inlinable
    public func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        action()
    }

    public var now: SchedulerTimeType { return SchedulerTimeType() }

    public var minimumTolerance: SchedulerTimeType.Stride { return 0 }

    public func schedule(after date: SchedulerTimeType,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) {
        action()
    }

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         tolerance: SchedulerTimeType.Stride,
                         options: SchedulerOptions?,
                         _ action: @escaping () -> Void) -> Cancellable {
        action()
        return Subscriptions.empty
    }
}
