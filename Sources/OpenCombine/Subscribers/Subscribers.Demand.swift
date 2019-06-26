//
//  Subscribers.Demand.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

// swiftlint:disable shorthand_operator - because of false positives here

extension Subscribers {

    /// A requested number of items, sent to a publisher from a subscriber via the subscription.
    ///
    /// - `unlimited`: A request for an unlimited number of items.
    /// - `max`: A request for a maximum number of items.
    public enum Demand: Comparable {

        /// Requests as many values as the `Publisher` can produce.
        case unlimited

        /// Limits the maximum number of values.
        /// The `Publisher` may send fewer than the requested number.
        /// Negative values will result in a `fatalError`.
        case max(Int)

        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        public static func + (lhs: Demand, rhs: Demand) -> Demand {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return .unlimited
            case (_, .unlimited):
                return .unlimited
            case let (.max(i), .max(j)):
                return .max(i + j)
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
            switch lhs {
            case .unlimited:
                return .unlimited
            case let .max(i):
                return .max(i * rhs)
            }
        }

        public static func *= (lhs: inout Demand, rhs: Int) {
            lhs = lhs * rhs
        }

        /// When subtracting any value (including `.unlimited`) from `.unlimited`, the result is still
        /// `.unlimited`. Subtracting `.unlimited` from any value (except `.unlimited`) results in
        /// `.max(0)`. A negative demand is possible, but be aware that it is not usable when requesting values in
        /// a subscription.
        public static func - (lhs: Demand, rhs: Demand) -> Demand {
            switch (lhs, rhs) {
            case (.unlimited, _):
                return .unlimited
            case (_, .unlimited):
                return .max(0)
            case let (.max(i), .max(j)):
                return .max(i - j)
            }
        }

        /// When subtracting any value (including `.unlimited`) from `.unlimited`, the result is still
        /// `.unlimited`. Subtracting `.unlimited` from any value (except `.unlimited`) results in
        /// `.max(0)`. A negative demand is possible, but be aware that it is not usable when requesting values in
        /// a subscription.
        public static func -= (lhs: inout Demand, rhs: Demand) {
            lhs = lhs - rhs
        }

        /// When subtracting any value from `.unlimited`, the result is still `.unlimited`. A negative demand is
        /// possible, but be aware that it is not usable when requesting values in a subscription.
        public static func - (lhs: Demand, rhs: Int) -> Demand {
            return lhs - .max(rhs)
        }

        /// When subtracting any value from `.unlimited`, the result is still `.unlimited`. A negative demand is
        /// possible, but be aware that it is not usable when requesting values in a subscription.
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
            switch (lhs, rhs) {
            case let (.max(i), .max(j)):
                return i < j
            case (.max, .unlimited):
                return true
            case (.unlimited, .unlimited), (.unlimited, .max):
                return false
            }
        }

        /// Returns `true` if `lhs` and `rhs` are equal. `.unlimited` is not equal to any integer.
        public static func == (lhs: Demand, rhs: Int) -> Bool {
            return lhs == .max(rhs)
        }

        /// Returns `true` if `lhs` and `rhs` are not equal. `.unlimited` is not equal to any integer.
        public static func != (lhs: Demand, rhs: Int) -> Bool {
            return lhs != .max(rhs)
        }

        /// Returns `true` if `lhs` and `rhs` are equal. `.unlimited` is not equal to any integer.
        public static func == (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) == rhs
        }

        /// Returns `true` if `lhs` and `rhs` are not equal. `.unlimited` is not equal to any integer.
        public static func != (lhs: Int, rhs: Demand) -> Bool {
            return .max(lhs) != rhs
        }

        /// Returns the number of requested values, or `nil` if `.unlimited`.
        public var max: Int? {
            switch self {
            case let .max(m):
                return m
            case .unlimited:
                return nil
            }
        }
    }
}
