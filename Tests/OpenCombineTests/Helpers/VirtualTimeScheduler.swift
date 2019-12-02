//
//  VirtualTimeScheduler.swift
//  OpenCombineTests
//
//  Created by Евгений Богомолов on 14/09/2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class VirtualTimeScheduler: Scheduler {

    struct SchedulerTimeType: Strideable, Comparable, Hashable {

        struct Stride: ExpressibleByFloatLiteral,
                       Comparable,
                       SignedNumeric,
                       SchedulerTimeIntervalConvertible
        {
            var magnitude: Int64

            fileprivate init(magnitude: Int64) {
                self.magnitude = magnitude
            }

            init(integerLiteral value: Int) {
                self = .seconds(value)
            }

            init(floatLiteral value: Double) {
                self = .seconds(value)
            }

            init?<Source: BinaryInteger>(exactly source: Source) {
                guard let magnitude = Int64(exactly: source) else {
                    return nil
                }
                self.init(magnitude: magnitude)
            }

            static func < (lhs: Stride, rhs: Stride) -> Bool {
                return lhs.magnitude < rhs.magnitude
            }

            static func * (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(magnitude: lhs.magnitude * rhs.magnitude)
            }

            static func + (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(magnitude: lhs.magnitude + rhs.magnitude)
            }

            static func - (lhs: Stride, rhs: Stride) -> Stride {
                return Stride(magnitude: lhs.magnitude - rhs.magnitude)
            }

            static func -= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude -= rhs.magnitude
            }

            static func *= (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude *= rhs.magnitude
            }

            static func += (lhs: inout Stride, rhs: Stride) {
                lhs.magnitude += rhs.magnitude
            }

            static func seconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value) * 1_000_000_000)
            }

            static func seconds(_ value: Double) -> Stride {
                return Stride(magnitude: Int64(value * 1_000_000_000))
            }

            static func milliseconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value) * 1_000_000)
            }

            static func microseconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value) * 1_000)
            }

            static func nanoseconds(_ value: Int) -> Stride {
                return Stride(magnitude: Int64(value))
            }
        }

        /// Time in virtual nanoseconds
        let time: UInt64

        init(nanoseconds time: UInt64) {
            self.time = time
        }

        static func == (lhs: SchedulerTimeType, rhs: SchedulerTimeType) -> Bool {
            return lhs.time == rhs.time
        }

        static func < (lhs: SchedulerTimeType, rhs: SchedulerTimeType) -> Bool {
            return lhs.time < rhs.time
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(time)
        }

        func distance(to other: SchedulerTimeType) -> Stride {
            if self > other {
                return Stride(magnitude: -Int64(time - other.time))
            } else {
                return Stride(magnitude: Int64(other.time - time))
            }
        }

        func advanced(by stride: Stride) -> SchedulerTimeType {
            return stride.magnitude < 0
                ? SchedulerTimeType(nanoseconds: time - UInt64(-stride.magnitude))
                : SchedulerTimeType(nanoseconds: time + UInt64(stride.magnitude))
        }

        static func + (lhs: SchedulerTimeType, rhs: Stride) -> SchedulerTimeType {
            return lhs.advanced(by: rhs)
        }
    }

    struct SchedulerOptions: Equatable {

        let value: Int

        init(_ value: Int) {
            self.value = value
        }
    }

    private struct EnqueuedAction: Comparable {
        let time: SchedulerTimeType
        let action: () -> Void

        init(time: SchedulerTimeType, action: @escaping () -> Void) {
            self.time = time
            self.action = action
        }

        static func < (lhs: EnqueuedAction, rhs: EnqueuedAction) -> Bool {
            return lhs.time > rhs.time
        }

        static func == (lhs: EnqueuedAction, rhs: EnqueuedAction) -> Bool {
            return lhs.time == rhs.time
        }
    }

    private final class CancellableToken: Cancellable {

        private(set) var isCancelled = false

        func cancel() {
            isCancelled = true
        }
    }

    enum Event: Equatable, CustomStringConvertible {
        case now
        case minimumTolerance
        case schedule(options: SchedulerOptions?)
        case scheduleAfterDate(SchedulerTimeType,
                               tolerance: SchedulerTimeType.Stride,
                               options: SchedulerOptions?)
        case scheduleAfterDateWithInterval(SchedulerTimeType,
                                           interval: SchedulerTimeType.Stride,
                                           tolerance: SchedulerTimeType.Stride,
                                           options: SchedulerOptions?)

        var description: String {

            func describeOptions(_ options: SchedulerOptions?) -> String {
                return options.map { ".init(\($0.value)" } ?? "nil"
            }

            func describeDate(_ date: SchedulerTimeType) -> String {
                return ".init(nanoseconds: \(date.time)"
            }

            func describeStride(_ stride: SchedulerTimeType.Stride) -> String {
                return ".nanoseconds(\(stride.magnitude))"
            }

            switch self {
            case .now:
                return ".now"
            case .minimumTolerance:
                return ".minimumTolerance"
            case let .schedule(options):
                return ".schedule(options: \(describeOptions(options)))"
            case let .scheduleAfterDate(date, tolerance, options):
                return """
                .scheduleAfterDate(\(describeDate(date)), \
                tolerance: \(describeStride(tolerance)), \
                options: \(describeOptions(options)))
                """
            case let .scheduleAfterDateWithInterval(date, interval, tolerance, options):
                return """
                .scheduleAfterDateWithInterval(\(describeDate(date)), \
                interval: \(describeStride(interval)), \
                tolerance: \(describeStride(tolerance)), \
                options: \(describeOptions(options)))
                """
            }
        }
    }

    private(set) var history = [Event]()

    private var _now = SchedulerTimeType(nanoseconds: 0)

    private var workQueue = PriorityQueue<EnqueuedAction>()

    var scheduledDates: [SchedulerTimeType] {
        return workQueue.map { $0.time }
    }

    var now: SchedulerTimeType {
        history.append(.now)
        return _now
    }

    var minimumTolerance: SchedulerTimeType.Stride {
        history.append(.minimumTolerance)
        return 0
    }

    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        history.append(.schedule(options: options))
        workQueue.insert(.init(time: _now, action: action))
    }

    func schedule(after date: SchedulerTimeType,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) {
        history.append(.scheduleAfterDate(date, tolerance: tolerance, options: options))
        workQueue.insert(.init(time: date, action: action))
    }

    func schedule(after date: SchedulerTimeType,
                  interval: SchedulerTimeType.Stride,
                  tolerance: SchedulerTimeType.Stride,
                  options: SchedulerOptions?,
                  _ action: @escaping () -> Void) -> Cancellable {
        history.append(.scheduleAfterDateWithInterval(date,
                                                      interval: interval,
                                                      tolerance: tolerance,
                                                      options: options))
        let cancellableToken = CancellableToken()
        repeatedlyExecute(after: date,
                          interval: interval,
                          cancellableToken: cancellableToken,
                          action: action)
        return cancellableToken
    }

    private func repeatedlyExecute(after date: SchedulerTimeType,
                                   interval: SchedulerTimeType.Stride,
                                   cancellableToken: CancellableToken,
                                   action: @escaping () -> Void) {
        let enqueuedAction = EnqueuedAction(time: date) { [unowned self] in
            if cancellableToken.isCancelled { return }
            action()
            self.repeatedlyExecute(after: date + interval,
                                   interval: interval,
                                   cancellableToken: cancellableToken,
                                   action: action)
        }
        workQueue.insert(enqueuedAction)
    }

    func executeScheduledActions() {
        while let enqueuedAction = workQueue.extractMax() {
            _now = enqueuedAction.time
            enqueuedAction.action()
        }
    }
}
