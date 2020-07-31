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
                let start = dispatchTime.rawValue
                let end = other.dispatchTime.rawValue
                return .nanoseconds(
                    end >= start
                        ? Int(Int64(bitPattern: end) - Int64(bitPattern: start))
                        : -Int(Int64(bitPattern: start) - Int64(bitPattern: end))
                )
            }

            /// Returns a dispatch queue scheduler time calculated by advancing
            /// this instance’s time by the given interval.
            ///
            /// - Parameter n: A time interval to advance.
            /// - Returns: A dispatch queue time advanced by the given
            ///   interval from this instance’s time.
            public func advanced(by stride: Stride) -> SchedulerTimeType {
                return stride.magnitude == .max
                    ? .init(.distantFuture)
                    : .init(dispatchTime + stride.timeInterval)
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
// This dance is to avoid the warning 'default will never be executed'
// on non-Darwin platforms.
// There really shouldn't be a warning.
// See https://forums.swift.org/t/unknown-default-produces-a-warning-on-linux-with-non-frozen-enum/31687
//
// Thanks to Jeremy David Giesbrecht for suggesting this workaround.
#if canImport(Darwin)
                    case .never:
                        self = .nanoseconds(.max)
                    @unknown default:
                        self.init(__guessFromUnknown: timeInterval)
#else
                    default:
                        if case .never = timeInterval {
                            self = .nanoseconds(.max)
                        } else {
                            self.init(__guessFromUnknown: timeInterval)
                        }
#endif
                    }
                }

                public // testable
                init(__guessFromUnknown timeInterval: DispatchTimeInterval) {
                    // Let's take some reference time,
                    // add `timeInterval` to it, take the `rawValue` from the result
                    // and subtract the `rawValue` of the reference time.
                    //
                    // We won't be able to provide the exact implementation though,
                    // because something will definitely overflow.
                    //
                    // However, we can try to support as wide a range of values
                    // as possible.
                    //
                    // By trial and error I got that the `rawValue` of `UInt64.max / 13`
                    // gives us probably the widest range of supported values:
                    // from `Int.min / 6.5` to `Int.max / 2.889` nanoseconds.
                    // That's with Int being 64 bits. Since here only UInt64 can overflow,
                    // when Int is 32 bits, we don't have this issue.
                    // It should be more than enough.

                    let referenceTime = DispatchTime(uptimeNanoseconds: .max / 13)
                    self = SchedulerTimeType(referenceTime)
                        .distance(to: SchedulerTimeType(referenceTime + timeInterval))
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
                    return Stride(magnitude: 0)
                }

                public static func + (lhs: Stride, rhs: Stride) -> Stride {
                    return Stride(magnitude: lhs.magnitude + rhs.magnitude)
                }

                public static func - (lhs: Stride, rhs: Stride) -> Stride {
                    return Stride(magnitude: lhs.magnitude - rhs.magnitude)
                }

                public static func -= (lhs: inout Stride, rhs: Stride) {
                    lhs.magnitude -= rhs.magnitude
                }

                public static func *= (lhs: inout Stride, rhs: Stride) {
                    lhs.magnitude = 0
                }

                public static func += (lhs: inout Stride, rhs: Stride) {
                    lhs.magnitude += rhs.magnitude
                }

                public static func seconds(_ value: Double) -> Stride {
                    return Stride(magnitude: Int(value * 1_000_000_000))
                }

                public static func seconds(_ value: Int) -> Stride {
                    return Stride(magnitude: clampedIntProduct(value, 1_000_000_000))
                }

                public static func milliseconds(_ value: Int) -> Stride {
                    return Stride(magnitude: clampedIntProduct(value, 1_000_000))
                }

                public static func microseconds(_ value: Int) -> Stride {
                    return Stride(magnitude: clampedIntProduct(value, 1_000))
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

    /// Options that affect the operation of the dispatch queue scheduler.
    public typealias SchedulerOptions = OCombine.SchedulerOptions

    /// The scheduler time type used by the dispatch queue.
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

// This function is taken from swift-corelibs-libdispatch:
// https://github.com/apple/swift-corelibs-libdispatch/blob/c992dacf3ca114806e6ac9ffc9113b19255be9fe/src/swift/Time.swift#L134-L144
//
// Returns m1 * m2, clamped to the range [Int.min, Int.max].
// Because of the way this function is used, we can always assume
// that m2 > 0.
private func clampedIntProduct(_ lhs: Int, _ rhs: Int) -> Int {
    assert(rhs > 0, "multiplier must be positive")
    let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    if overflow {
        return lhs > 0 ? .max : .min
    }
    return result
}
