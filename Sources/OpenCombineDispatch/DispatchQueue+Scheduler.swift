//
//  DispatchQueue.swift
//
//
//  Created by Sergej Jaskiewicz on 21.08.2019.
//

import Dispatch
import OpenCombine

extension DispatchQueue {

    /// A namespace for disambiguation when both OpenCombine and Combine are imported.
    ///
    /// Combine extends `DispatchQueue` with new methods and nested types.
    /// If you import both OpenCombine and Combine (either explicitly or implicitly,
    /// e. g. when importing Foundation), you will not be able
    /// to write `DispatchQueue.SchedulerTimeType`,
    /// because Swift is unable to understand which `SchedulerTimeType`
    /// you're referring to.
    ///
    /// So you have to write `DispatchQueue.OCombine.SchedulerTimeType`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine: Scheduler {

        public let queue: DispatchQueue

        public init(_ queue: DispatchQueue) {
            self.queue = queue
        }

        /// The scheduler time type used by the dispatch queue.
        public struct SchedulerTimeType: Strideable, Codable, Hashable {

            /// The dispatch time represented by this type.
            public var dispatchTime: DispatchTime

            /// Creates a dispatch queue time type instance.
            ///
            /// - Parameter time: The dispatch time to represent.
            public init(_ time: DispatchTime) {
                dispatchTime = time
            }

            /// Returns the distance to another dispatch queue time.
            ///
            /// - Parameter other: Another dispatch queue time.
            /// - Returns: The time interval between this time and the provided time.
            public func distance(to other: SchedulerTimeType) -> Stride {
                return .nanoseconds(
                    Int(other.dispatchTime.rawValue - dispatchTime.rawValue)
                )
            }

            /// Returns a dispatch queue scheduler time calculated by advancing
            /// this instance’s time by the given interval.
            ///
            /// - Parameter n: A time interval to advance.
            /// - Returns: A dispatch queue time advanced by the given
            ///   interval from this instance’s time.
            public func advanced(by stride: Stride) -> SchedulerTimeType {
                return .init(dispatchTime + stride.timeInterval)
            }

            public func hash(into hasher: inout Hasher) {
                hasher.combine(dispatchTime.rawValue)
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(dispatchTime.uptimeNanoseconds)
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                dispatchTime = try .init(uptimeNanoseconds: container.decode(UInt64.self))
            }

            /// A type that represents the distance between two values.
            public struct Stride: SchedulerTimeIntervalConvertible,
                                  Comparable,
                                  SignedNumeric,
                                  ExpressibleByFloatLiteral,
                                  Hashable,
                                  Codable {

                /// If created via floating point literal, the value is
                /// converted to nanoseconds via multiplication.
                public typealias FloatLiteralType = Double

                /// Nanoseconds, same as DispatchTimeInterval.
                public typealias IntegerLiteralType = Int

                /// A type that can represent the absolute value of any possible
                /// value of the conforming type.
                public typealias Magnitude = Int

                /// The value of this time interval in nanoseconds.
                public var magnitude: Int

                /// A `DispatchTimeInterval` created with the value of this type
                /// in nanoseconds.
                public var timeInterval: DispatchTimeInterval {
                    return .nanoseconds(magnitude)
                }

                private init(magnitude: Int) {
                    self.magnitude = magnitude
                }

                /// Creates a dispatch queue time interval from the given
                /// dispatch time interval.
                ///
                /// - Parameter timeInterval: A dispatch time interval.
                public init(_ timeInterval: DispatchTimeInterval) {
                    switch timeInterval {
                    case .seconds(let seconds):
                        self = .seconds(seconds)
                    case .milliseconds(let milliseconds):
                        self = .milliseconds(milliseconds)
                    case .microseconds(let microseconds):
                        self = .microseconds(microseconds)
                    case .nanoseconds(let nanoseconds):
                        self = .nanoseconds(nanoseconds)
                    case .never:
                        fallthrough
                    @unknown default:
                        self = .nanoseconds(.max)
                    }
                }

                /// Creates a dispatch queue time interval from a floating-point
                /// seconds value.
                ///
                /// - Parameter value: The number of seconds, as a `Double`.
                public init(floatLiteral value: Double) {
                    self = .seconds(value)
                }

                /// Creates a dispatch queue time interval from an integer seconds value.
                ///
                /// - Parameter value: The number of seconds, as an `Int`.
                public init(integerLiteral value: Int) {
                    self = .seconds(value)
                }

                /// Creates a dispatch queue time interval from a binary integer type.
                ///
                /// If `exactly` cannot convert to an `Int`, the resulting time interval
                /// is `nil`.
                /// 
                /// - Parameter exactly: A binary integer representing a time interval.
                public init?<Source: BinaryInteger>(exactly source: Source) {
                    guard let value = Int(exactly: source) else { return nil }
                    self = .nanoseconds(value)
                }

                public static func < (lhs: Stride, rhs: Stride) -> Bool {
                    return lhs.magnitude < rhs.magnitude
                }

                public static func * (lhs: Stride, rhs: Stride) -> Stride {
                    // A bug in Combine, should be nanoseconds (FB7189676)
                    return .seconds(lhs.magnitude * rhs.magnitude)
                }

                public static func + (lhs: Stride, rhs: Stride) -> Stride {
                    // A bug in Combine, should be nanoseconds (FB7189676)
                    return .seconds(lhs.magnitude + rhs.magnitude)
                }

                public static func - (lhs: Stride, rhs: Stride) -> Stride {
                    // A bug in Combine, should be nanoseconds (FB7189676)
                    return .seconds(lhs.magnitude - rhs.magnitude)
                }

                // swiftlint:disable shorthand_operator

                public static func -= (lhs: inout Stride, rhs: Stride) {
                    lhs = lhs - rhs
                }

                public static func *= (lhs: inout Stride, rhs: Stride) {
                    lhs = lhs * rhs
                }

                public static func += (lhs: inout Stride, rhs: Stride) {
                    lhs = lhs + rhs
                }

                // swiftlint:enable shorthand_operator

                public static func seconds(_ value: Double) -> Stride {
                    return Stride(magnitude: Int(value * 1_000_000_000))
                }

                public static func seconds(_ value: Int) -> Stride {
                    return Stride(magnitude: value * 1_000_000_000)
                }

                public static func milliseconds(_ value: Int) -> Stride {
                    return Stride(magnitude: value * 1_000_000)
                }

                public static func microseconds(_ value: Int) -> Stride {
                    return Stride(magnitude: value * 1_000)
                }

                public static func nanoseconds(_ value: Int) -> Stride {
                    return Stride(magnitude: value)
                }
            }
        }

        /// Options that affect the operation of the dispatch queue scheduler.
        public struct SchedulerOptions {

            /// The dispatch queue quality of service.
            public var qos: DispatchQoS

            /// The dispatch queue work item flags.
            public var flags: DispatchWorkItemFlags

            /// The dispatch group, if any, that should be used for performing actions.
            public var group: DispatchGroup?

            public init(qos: DispatchQoS = .unspecified,
                        flags: DispatchWorkItemFlags = [],
                        group: DispatchGroup? = nil) {
                self.qos = qos
                self.flags = flags
                self.group = group
            }
        }

        public var minimumTolerance: SchedulerTimeType.Stride {
            return .nanoseconds(0)
        }

        public var now: SchedulerTimeType {
            return .init(.now())
        }

        public func schedule(options: SchedulerOptions?,
                             _ action: @escaping () -> Void) {
            let options = options ?? .init()
            queue.async(group: options.group,
                        qos: options.qos,
                        flags: options.flags,
                        execute: action)
        }

        public func schedule(after date: SchedulerTimeType,
                             tolerance: SchedulerTimeType.Stride,
                             options: SchedulerOptions?,
                             _ action: @escaping () -> Void) {
            let options = options ?? .init()
            queue.asyncAfter(deadline: date.dispatchTime,
                             qos: options.qos,
                             flags: options.flags,
                             execute: action)
        }

        /// Performs the action at some time after the specified date, at the specified
        /// frequency, optionally taking into account tolerance if possible.
        public func schedule(after date: SchedulerTimeType,
                             interval: SchedulerTimeType.Stride,
                             tolerance: SchedulerTimeType.Stride,
                             options: SchedulerOptions?,
                             _ action: @escaping () -> Void) -> Cancellable {
            let options = options ?? .init()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.setEventHandler(qos: options.qos,
                                  flags: options.flags,
                                  handler: action)
            timer.schedule(deadline: date.dispatchTime,
                           repeating: interval.timeInterval,
                           leeway: tolerance.timeInterval)
            timer.resume()
            return AnyCancellable(timer.cancel)
        }
    }

    /// A namespace for disambiguation when both OpenCombine and Combine are imported.
    ///
    /// Combine extends `DispatchQueue` with new methods and nested types.
    /// If you import both OpenCombine and Combine (either explicitly or implicitly,
    /// e. g. when importing Foundation), you will not be able
    /// to write `DispatchQueue.main.schedule { doThings() }`,
    /// because Swift is unable to understand which `schedule` method
    /// you're referring to.
    ///
    /// So you have to write `DispatchQueue.main.ocombine.schedule { doThings() }`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public var ocombine: OCombine {
        return OCombine(self)
    }
}

#if !canImport(Combine)
extension DispatchQueue: OpenCombine.Scheduler {

    public typealias SchedulerOptions = OCombine.SchedulerOptions

    public typealias SchedulerTimeType = OCombine.SchedulerTimeType

    public var minimumTolerance: OCombine.SchedulerTimeType.Stride {
        return ocombine.minimumTolerance
    }

    public var now: OCombine.SchedulerTimeType {
        return ocombine.now
    }

    public func schedule(options: OCombine.SchedulerOptions?,
                         _ action: @escaping () -> Void) {
        ocombine.schedule(options: options, action)
    }

    public func schedule(after date: OCombine.SchedulerTimeType,
                         tolerance: OCombine.SchedulerTimeType.Stride,
                         options: OCombine.SchedulerOptions?,
                         _ action: @escaping () -> Void) {
        ocombine.schedule(after: date, tolerance: tolerance, options: options, action)
    }

    public func schedule(after date: OCombine.SchedulerTimeType,
                         interval: OCombine.SchedulerTimeType.Stride,
                         tolerance: OCombine.SchedulerTimeType.Stride,
                         options: OCombine.SchedulerOptions?,
                         _ action: @escaping () -> Void) -> Cancellable {
        return ocombine.schedule(after: date,
                                 interval: interval,
                                 tolerance: tolerance,
                                 options: options,
                                 action)
    }
}
#endif
