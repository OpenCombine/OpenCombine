//
//  Subscribers.Demand.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

// swiftlint:disable shorthand_operator - because of false positives here

extension Subscribers {

    /// A requested number of items, sent to a publisher from a subscriber via
    /// the subscription.
    ///
    /// - `unlimited`: A request for an unlimited number of items.
    /// - `max`: A request for a maximum number of items.
    public struct Demand: Equatable,
                          Comparable,
                          Hashable,
                          Codable,
                          CustomStringConvertible
    {
        @usableFromInline
        internal let rawValue: UInt

        @inline(__always)
        @inlinable
        internal init(rawValue: UInt) {
            self.rawValue = min(UInt(Int.max) + 1, rawValue)
        }

        /// Requests as many values as the `Publisher` can produce.
        public static let unlimited = Demand(rawValue: .max)

        /// A demand for no items.
        ///
        /// This is equivalent to `Demand.max(0)`.
        public static let none = Demand.max(0)

        /// Limits the maximum number of values.
        /// The `Publisher` may send fewer than the requested number.
        /// Negative values will result in a `fatalError`.
        @inline(__always)
        @inlinable
        public static func max(_ value: Int) -> Demand {
            precondition(value >= 0, "demand cannot be negative")
            return Demand(rawValue: UInt(value))
        }

        public var description: String {
            if self == .unlimited {
                return "unlimited"
            } else {
                return "max(\(rawValue))"
            }
        }

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func + (lhs: Demand, rhs: Demand) -> Demand {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return .unlimited
            case (_, .unlimited):
                return .unlimited
            default:
                let (sum, isOverflow) = Int(lhs.rawValue)
                    .addingReportingOverflow(Int(rhs.rawValue))
                return isOverflow ? .unlimited : .max(sum)
            }
        }

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func += (lhs: inout Demand, rhs: Demand) {
            if lhs == .unlimited { return }
            lhs = lhs + rhs
        }

        /// When adding any value to` .unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func + (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            }
            let (sum, isOverflow) = Int(lhs.rawValue).addingReportingOverflow(rhs)
            return isOverflow ? .unlimited : .max(sum)
        }

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func += (lhs: inout Demand, rhs: Int) {
            lhs = lhs + rhs
        }

        public static func * (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            }
            let (product, isOverflow) = Int(lhs.rawValue)
                .multipliedReportingOverflow(by: rhs)
            return isOverflow ? .unlimited : .max(product)
        }

        @inline(__always)
        @inlinable
        public static func *= (lhs: inout Demand, rhs: Int) {
            lhs = lhs * rhs
        }

        /// When subtracting any value (including `.unlimited`) from `.unlimited`,
        /// the result is still `.unlimited`. Subtracting `.unlimited` from any value
        /// (except `.unlimited`) results in `.max(0)`. A negative demand is not possible;
        /// any operation that would result in a negative value is clamped to `.max(0)`.
        @inline(__always)
        @inlinable
        public static func - (lhs: Demand, rhs: Demand) -> Demand {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return .unlimited
            case (_, .unlimited):
                return .none
            default:
                let (difference, isOverflow) = Int(lhs.rawValue)
                    .subtractingReportingOverflow(Int(rhs.rawValue))
                return isOverflow ? .none : .max(difference)
            }
        }

        /// When subtracting any value (including `.unlimited`) from `.unlimited`,
        /// the result is still `.unlimited`. Subtracting unlimited from any value
        /// (except `.unlimited`) results in `.max(0)`. A negative demand is not possible;
        /// any operation that would result in a negative value is clamped to `.max(0)`.
        /// but be aware that it is not usable when requesting values in a subscription.
        @inline(__always)
        @inlinable
        public static func -= (lhs: inout Demand, rhs: Demand) {
            lhs = lhs - rhs
        }

        /// When subtracting any value from `.unlimited`, the result is still
        /// `.unlimited`.
        /// A negative demand is not possible; any operation that would result in
        /// a negative value is clamped to `.max(0)`
        @inline(__always)
        @inlinable
        public static func - (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            }

            let (difference, isOverflow) = Int(lhs.rawValue)
                .subtractingReportingOverflow(rhs)
            return isOverflow ? .none : .max(difference)
        }

        /// When subtracting any value from `.unlimited,` the result is still
        /// `.unlimited`.
        /// A negative demand is not possible; any operation that would result in
        /// a negative value is clamped to `.max(0)`
        @inline(__always)
        @inlinable
        public static func -= (lhs: inout Demand, rhs: Int) {
            if lhs == .unlimited { return }
            lhs = lhs - rhs
        }

        @inline(__always)
        @inlinable
        public static func > (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return true
            } else {
                return Int(lhs.rawValue) > rhs
            }
        }

        @inline(__always)
        @inlinable
        public static func >= (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return true
            } else {
                return Int(lhs.rawValue) >= rhs
            }
        }

        @inline(__always)
        @inlinable
        public static func > (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return false
            } else {
                return lhs > Int(rhs.rawValue)
            }
        }

        @inline(__always)
        @inlinable
        public static func >= (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return false
            } else {
                return lhs >= Int(rhs.rawValue)
            }
        }

        @inline(__always)
        @inlinable
        public static func < (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return false
            } else {
                return Int(lhs.rawValue) < rhs
            }
        }

        @inline(__always)
        @inlinable
        public static func < (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return true
            } else {
                return lhs < Int(rhs.rawValue)
            }
        }

        @inline(__always)
        @inlinable
        public static func <= (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return false
            } else {
                return Int(lhs.rawValue) <= rhs
            }
        }

        @inline(__always)
        @inlinable
        public static func <= (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return true
            } else {
                return lhs <= Int(rhs.rawValue)
            }
        }

        /// If `lhs` is `.unlimited`, then the result is always `false`.
        /// If `rhs` is `.unlimited` then the result is `false` iff `lhs` is `.unlimited`
        /// Otherwise, the two `.max` values are compared.
        @inline(__always)
        @inlinable
        public static func < (lhs: Demand, rhs: Demand) -> Bool {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return false
            case (_, .unlimited):
                return true
            default:
                return lhs.rawValue < rhs.rawValue
            }
        }

        @inline(__always)
        @inlinable
        public static func <= (lhs: Demand, rhs: Demand) -> Bool {
            switch (lhs, rhs) {
            case (.unlimited, .unlimited):
                return true
            case (.unlimited, _):
                return false
            case (_, .unlimited):
                return true
            default:
                return lhs.rawValue <= rhs.rawValue
            }
        }

        @inline(__always)
        @inlinable
        public static func >= (lhs: Demand, rhs: Demand) -> Bool {
            switch (lhs, rhs) {
            case (.unlimited, .unlimited):
                return true
            case (.unlimited, _):
                return true
            case (_, .unlimited):
                return false
            default:
                return lhs.rawValue >= rhs.rawValue
            }
        }

        @inline(__always)
        @inlinable
        public static func > (lhs: Demand, rhs: Demand) -> Bool {
            switch (lhs, rhs) {
            case (.unlimited, .unlimited):
                return false
            case (.unlimited, _):
                return true
            case (_, .unlimited):
                return false
            default:
                return lhs.rawValue > rhs.rawValue
            }
        }

        /// Returns `true` if `lhs` and `rhs` are equal. `.unlimited` is not equal to any
        /// integer.
        @inline(__always)
        @inlinable
        public static func == (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return false
            } else {
                return Int(lhs.rawValue) == rhs
            }
        }

        /// Returns `true` if `lhs` and `rhs` are not equal. `.unlimited` is not equal to
        /// any integer.
        public static func != (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return true
            } else {
                return Int(lhs.rawValue) != rhs
            }
        }

        /// Returns `true` if `lhs` and `rhs` are equal. `.unlimited` is not equal to any
        /// integer.
        public static func == (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return false
            } else {
                return rhs.rawValue == lhs
            }
        }

        /// Returns `true` if `lhs` and `rhs` are not equal. `.unlimited` is not equal to
        /// any integer.
        public static func != (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return true
            } else {
                return Int(rhs.rawValue) != lhs
            }
        }

        /// Returns the number of requested values, or `nil` if `.unlimited`.
        public var max: Int? {
            if self == .unlimited {
                return nil
            } else {
                return Int(rawValue)
            }
        }

        public init(from decoder: Decoder) throws {
            try self.init(rawValue: decoder.singleValueContainer().decode(UInt.self))
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }
}
