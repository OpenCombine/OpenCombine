//
//  Scheduler.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

/// A protocol that provides a scheduler with an expression for relative time.
public protocol SchedulerTimeIntervalConvertible {

    /// Converts the specified number of seconds into an instance of this scheduler time
    /// type.
    static func seconds(_ s: Int) -> Self

    /// Converts the specified number of seconds, as a floating-point value, into
    /// an instance of this scheduler time type.
    static func seconds(_ s: Double) -> Self

    /// Converts the specified number of milliseconds into an instance of this scheduler
    /// time type.
    static func milliseconds(_ ms: Int) -> Self

    /// Converts the specified number of microseconds into an instance of this scheduler
    /// time type.
    static func microseconds(_ us: Int) -> Self

    /// Converts the specified number of nanoseconds into an instance of this scheduler
    /// time type.
    static func nanoseconds(_ ns: Int) -> Self
}

/// A protocol that defines when and how to execute a closure.
///
/// You can use a scheduler to execute code as soon as possible, or after a future date.
/// Individual scheduler implementations use whatever time-keeping system makes sense
/// for them. Schedulers express this as their `SchedulerTimeType`. Since this type
/// conforms to `SchedulerTimeIntervalConvertible`, you can always express these times
/// with the convenience functions like `.milliseconds(500)`. Schedulers can accept
/// options to control how they execute the actions passed to them. These options may
/// control factors like which threads or dispatch queues execute the actions.
public protocol Scheduler {

    /// Describes an instant in time for this scheduler.
    associatedtype SchedulerTimeType: Strideable
        where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible

    /// A type that defines options accepted by the scheduler.
    ///
    /// This type is freely definable by each `Scheduler`. Typically, operations that
    /// take a `Scheduler` parameter will also take `SchedulerOptions`.
    associatedtype SchedulerOptions

    /// This scheduler’s definition of the current moment in time.
    var now: SchedulerTimeType { get }

    /// The minimum tolerance allowed by the scheduler.
    var minimumTolerance: SchedulerTimeType.Stride { get }

    /// Performs the action at the next possible opportunity.
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date.
    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void)

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, optionally taking into account tolerance if possible.
    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable
}

extension Scheduler {

    /// Performs the action at some time after the specified date, using the scheduler’s
    /// minimum tolerance.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         _ action: @escaping () -> Void) {
        schedule(after: date, tolerance: minimumTolerance, action)
    }

    /// Performs the action at the next possible opportunity, without options.
    @inlinable
    public func schedule(_ action: @escaping () -> Void) {
        schedule(options: nil, action)
    }

    /// Performs the action at some time after the specified date.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         tolerance: SchedulerTimeType.Stride,
                         _ action: @escaping () -> Void) {
        schedule(after: date, tolerance: tolerance, options: nil, action)
    }

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, taking into account tolerance if possible.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         tolerance: SchedulerTimeType.Stride,
                         _ action: @escaping () -> Void) -> Cancellable {
        return schedule(after: date,
                        interval: interval,
                        tolerance: tolerance,
                        options: nil,
                        action)
    }

    /// Performs the action at some time after the specified date, at the specified
    /// frequency, using minimum tolerance possible for this Scheduler.
    ///
    /// The immediate scheduler ignores `date` and performs the action immediately.
    @inlinable
    public func schedule(after date: SchedulerTimeType,
                         interval: SchedulerTimeType.Stride,
                         _ action: @escaping () -> Void) -> Cancellable {
        return schedule(after: date,
                        interval: interval,
                        tolerance: minimumTolerance,
                        action)
    }
}
