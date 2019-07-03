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
        private var rawValue: UInt

        private init(_ rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Requests as many values as the `Publisher` can produce.
        public static let unlimited = Subscribers.Demand(UInt(Int.max) + 1)

        /// Limits the maximum number of values.
        /// The `Publisher` may send fewer than the requested number.
        /// Negative values will result in a `fatalError`.
        public static func max(_ value: Int) -> Subscribers.Demand {
            return .init(UInt(value))
        }

        public var description: String {
            if self == .unlimited {
                return "unlimited"
            } else {
                return "max(\(rawValue))"
            }
        }

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        public static func + (lhs: Demand, rhs: Demand) -> Demand {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return .unlimited
            case (_, .unlimited):
                return .unlimited
            default:
                let (sum, isOverflow) = lhs.rawValue.addingReportingOverflow(rhs.rawValue)
                return isOverflow ? .unlimited : .init(sum)
            }
        }

        /// A demand for no items.
        ///
        /// This is equivalent to `Demand.max(0)`.
        public static let none: Demand = .max(0)

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        public static func += (lhs: inout Demand, rhs: Demand) {
            lhs = lhs + rhs
        }

        /// When adding any value to` .unlimited`, the result is `.unlimited`.
        public static func + (lhs: Demand, rhs: Int) -> Demand {
            return lhs + .max(rhs)
        }

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        public static func += (lhs: inout Demand, rhs: Int) {
            lhs = lhs + rhs
        }

        public static func * (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            }

            let (product, isOverflow) =
                lhs.rawValue.multipliedReportingOverflow(by: UInt(rhs))

            return isOverflow ? .unlimited : .init(product)
        }

        public static func *= (lhs: inout Demand, rhs: Int) {
            lhs = lhs * rhs
        }

        /// When subtracting any value (including .unlimited) from .unlimited,
        /// the result is still .unlimited. Subtracting unlimited from any value
        /// (except unlimited) results in .max(0). A negative demand is not possible;
        /// any operation that would result in a negative value is clamped to .max(0).
        public static func - (lhs: Demand, rhs: Demand) -> Demand {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return .unlimited
            case (_, .unlimited):
                return .none
            default:
                let (difference, isOverflow) =
                    lhs.rawValue.subtractingReportingOverflow(rhs.rawValue)
                return isOverflow ? .none : .init(difference)
            }
        }

        /// When subtracting any value (including .unlimited) from .unlimited,
        /// the result is still .unlimited. Subtracting unlimited from any value
        /// (except unlimited) results in .max(0). A negative demand is not possible;
        /// any operation that would result in a negative value is clamped to .max(0).
        /// but be aware that it is not usable when requesting values in a subscription.
        public static func -= (lhs: inout Demand, rhs: Demand) {
            lhs = lhs - rhs
        }

        /// When subtracting any value from .unlimited, the result is still .unlimited.
        /// A negative demand is not possible; any operation that would result in
        /// a negative value is clamped to .max(0)
        public static func - (lhs: Demand, rhs: Int) -> Demand {
            return lhs - .max(rhs)
        }

        /// When subtracting any value from .unlimited, the result is still .unlimited.
        /// A negative demand is not possible; any operation that would result in
        /// a negative value is clamped to .max(0)
        public static func -= (lhs: inout Demand, rhs: Int) {
            lhs = lhs - rhs
        }

        public static func > (lhs: Demand, rhs: Int) -> Bool {
            return lhs > .max(rhs)
        }

        public static func >= (lhs: Demand, rhs: Int) -> Bool {
            return lhs >= .max(rhs)
        }

        public static func > (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) > rhs
        }

        public static func >= (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) >= rhs
        }

        public static func < (lhs: Demand, rhs: Int) -> Bool {
            return lhs < .max(rhs)
        }

        public static func < (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) < rhs
        }

        public static func <= (lhs: Demand, rhs: Int) -> Bool {
            return lhs <= .max(rhs)
        }

        public static func <= (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) <= rhs
        }

        /// If `lhs` is `.unlimited`, then the result is always `false`.
        /// If `rhs` is `.unlimited` then the result is `false` iff `lhs` is `.unlimited`
        /// Otherwise, the two `.max` values are compared.
        public static func < (lhs: Demand, rhs: Demand) -> Bool {
            if lhs == .unlimited {
                return false
            }

            if rhs == .unlimited {
                return true
            }

            return lhs.rawValue < rhs.rawValue
        }

        /// Returns `true` if `lhs` and `rhs` are equal. `.unlimited` is not equal to any
        /// integer.
        public static func == (lhs: Demand, rhs: Int) -> Bool {
            return lhs == .max(rhs)
        }

        /// Returns `true` if `lhs` and `rhs` are not equal. `.unlimited` is not equal to
        /// any integer.
        public static func != (lhs: Demand, rhs: Int) -> Bool {
            return lhs != .max(rhs)
        }

        /// Returns `true` if `lhs` and `rhs` are equal. `.unlimited` is not equal to any
        /// integer.
        public static func == (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) == rhs
        }

        /// Returns `true` if `lhs` and `rhs` are not equal. `.unlimited` is not equal to
        /// any integer.
        public static func != (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) != rhs
        }

        /// Returns the number of requested values, or `nil` if `.unlimited`.
        public var max: Int? {
            if self == .unlimited {
                return nil
            } else {
                return Int(rawValue)
            }
        }
    }
}
