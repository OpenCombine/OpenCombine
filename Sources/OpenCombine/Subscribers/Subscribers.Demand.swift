//
//  Subscribers.Demand.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

// swiftlint:disable attributes

#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

extension Subscribers {

    /// A requested number of items, sent to a publisher from a subscriber through the subscription.
    @frozen
    public struct Demand: Equatable, Comparable, Hashable, Codable, CustomStringConvertible {
        @usableFromInline
        internal let rawValue: UInt

        @inline(__always)
        @inlinable
        internal init(rawValue: UInt) {
            self.rawValue = min(UInt(Int.max) + 1, rawValue)
        }

        /// A request for as many values as the publisher can produce.
        public static let unlimited = Demand(rawValue: .max)

        /// A request for no elements from the publisher.
        ///
        /// This is equivalent to `Demand.max(0)`.
        public static let none = Demand(rawValue: .zero)

        /// Creates a demand for the given maximum number of elements.
        ///
        /// The publisher is free to send fewer than the requested maximum number of
        /// elements.
        ///
        /// - Parameter value: The maximum number of elements. Providing a negative value
        /// for this parameter results in a fatal error.
        @inline(__always)
        @inlinable
        public static func max(_ value: Int) -> Demand {
            precondition(value >= 0, "Demand cannot be negative")
            return Demand(rawValue: UInt(value))
        }

        public var description: String {
            if self == .unlimited {
                return "unlimited"
            } else {
                return "max(\(rawValue))"
            }
        }

        /// Returns the result of adding two demands.
        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func + (lhs: Demand, rhs: Demand) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            } else {
                if rhs == .unlimited {
                    return .unlimited
                } else {
                    let lhsValue: Int = numericCast(lhs.rawValue)
                    let rhsvalue: Int = numericCast(rhs.rawValue)
                    let r = lhsValue.addingReportingOverflow(rhsvalue)
                    if r.overflow {
                        return .unlimited
                    } else {
                        return .max(r.partialValue)
                    }
                }
            }
        }

        /// Adds two demands, and assigns the result to the first demand.
        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func += (lhs: inout Demand, rhs: Demand) {
            if lhs == .unlimited { return }
            lhs = lhs + rhs
        }

        /// Returns the result of adding an integer to a demand.
        /// When adding any value to` .unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func + (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            } else {
                let lhsValue: Int = numericCast(lhs.rawValue)
                let r = lhsValue.addingReportingOverflow(rhs)
                if r.overflow {
                    return .unlimited
                } else {
                    return .max(r.partialValue)
                }
            }
        }

        /// Adds an integer to a demand, and assigns the result to the demand.
        /// When adding any value to `.unlimited`, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func += (lhs: inout Demand, rhs: Int) {
            lhs = lhs + rhs
        }

        /// Returns the result of multiplying a demand by an integer.
        /// When multiplying any value by `.unlimited`, the result is `.unlimited`. If
        /// the multiplication operation overflows, the result is `.unlimited`.
        public static func * (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            } else {
                let lhsValue: Int = numericCast(lhs.rawValue)
                let r = lhsValue.multipliedReportingOverflow(by: rhs)
                if r.overflow {
                    return .unlimited
                } else {
                    return .max(r.partialValue)
                }
            }
        }

        /// Multiplies a demand by an integer, and assigns the result to the demand.
        /// When multiplying any value by `.unlimited`, the result is `.unlimited`. If
        /// the multiplication operation overflows, the result is `.unlimited`.
        @inline(__always)
        @inlinable
        public static func *= (lhs: inout Demand, rhs: Int) {
            lhs = lhs * rhs
        }

        /// Returns the result of subtracting one demand from another.
        /// When subtracting any value (including `.unlimited`) from `.unlimited`,
        /// the result is still `.unlimited`. Subtracting `.unlimited` from any value
        /// (except `.unlimited`) results in `.max(0)`. A negative demand is not possible;
        /// any operation that would result in a negative value is clamped to `.max(0)`.
        @inline(__always)
        @inlinable
        public static func - (lhs: Demand, rhs: Demand) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            } else {
                if rhs == .unlimited {
                    return .none
                } else {
                    let lhsValue: Int = numericCast(lhs.rawValue)
                    let rhsValue: Int = numericCast(rhs.rawValue)
                    let r = lhsValue.subtractingReportingOverflow(rhsValue)
                    if r.overflow {
                        return .max(0)
                    } else {
                        return .max(r.partialValue)
                    }
                }
            }
        }

        /// Subtracts one demand from another, and assigns the result to the first demand.
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

        /// Returns the result of subtracting an integer from a demand.
        /// When subtracting any value from `.unlimited`, the result is still
        /// `.unlimited`.
        /// A negative demand is not possible; any operation that would result in
        /// a negative value is clamped to `.max(0)`
        @inline(__always)
        @inlinable
        public static func - (lhs: Demand, rhs: Int) -> Demand {
            if lhs == .unlimited {
                return .unlimited
            } else {
                let lhsValue: Int = numericCast(lhs.rawValue)
                let r = lhsValue.subtractingReportingOverflow(rhs)
                if r.overflow {
                    return .max(0)
                } else {
                    return .max(r.partialValue)
                }
            }
        }

        /// Subtracts an integer from a demand, and assigns the result to the demand.
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

        /// Returns a Boolean that indicates whether the demand requests more than
        /// the given number of elements.
        /// If `lhs` is `.unlimited`, then the result is always `true`.
        /// Otherwise, the operator compares the demand’s `max` value to `rhs`.
        @inline(__always)
        @inlinable
        public static func > (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return true
            } else {
                return numericCast(lhs.rawValue) > rhs
            }
        }

        /// Returns a Boolean that indicates whether the first demand requests more or
        /// the same number of elements as the second.
        /// If `lhs` is `.unlimited`, then the result is always `true`.
        /// Otherwise, the operator compares the demand’s `max` value to `rhs`.
        @inline(__always)
        @inlinable
        public static func >= (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return true
            } else {
                return numericCast(lhs.rawValue) >= rhs
            }
        }

        /// Returns a Boolean that indicates a given number of elements is greater than
        /// the maximum specified by the demand.
        /// If `rhs` is `.unlimited`, then the result is always `false`.
        /// Otherwise, the operator compares the demand’s `max` value to `lhs`.
        @inline(__always)
        @inlinable
        public static func > (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return false
            } else {
                return lhs > numericCast(rhs.rawValue)
            }
        }

        /// Returns a Boolean that indicates a given number of elements is greater than
        /// or equal to the maximum specified by the demand.
        /// If `rhs` is `.unlimited`, then the result is always `false`.
        /// Otherwise, the operator compares the demand’s `max` value to `lhs`.
        @inline(__always)
        @inlinable
        public static func >= (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return false
            } else {
                return lhs >= numericCast(rhs.rawValue)
            }
        }

        /// Returns a Boolean that indicates whether the demand requests fewer than
        /// the given number of elements.
        /// If `lhs` is `.unlimited`, then the result is always `false`.
        /// Otherwise, the operator compares the demand’s `max` value to `rhs`.
        @inline(__always)
        @inlinable
        public static func < (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return false
            } else {
                return numericCast(lhs.rawValue) < rhs
            }
        }

        /// Returns a Boolean that indicates a given number of elements is less than
        /// the maximum specified by the demand.
        /// If `rhs` is `.unlimited`, then the result is always `true`.
        /// Otherwise, the operator compares the demand’s `max` value to `lhs`.
        @inline(__always)
        @inlinable
        public static func < (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return true
            } else {
                return lhs < numericCast(rhs.rawValue)
            }
        }

        /// Returns a Boolean that indicates whether the demand requests fewer or
        /// the same number of elements as the given integer.
        /// If `lhs` is `.unlimited`, then the result is always `false`.
        /// Otherwise, the operator compares the demand’s `max` value to `rhs`.
        @inline(__always)
        @inlinable
        public static func <= (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return false
            } else {
                return numericCast(lhs.rawValue) <= rhs
            }
        }

        /// Returns a Boolean value that indicates a given number of elements is less
        /// than or equal the maximum specified by the demand.
        /// If `rhs` is `.unlimited`, then the result is always `true`.
        /// Otherwise, the operator compares the demand’s `max` value to `lhs`.
        @inline(__always)
        @inlinable
        public static func <= (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return true
            } else {
                return lhs <= numericCast(rhs.rawValue)
            }
        }

        /// Returns a Boolean value that indicates whether the first demand requests fewer
        /// elements than the second.
        /// If both sides are `.unlimited`, the result is always `false`.
        /// If `lhs` is `.unlimited`, then the result is always `false`.
        /// If `rhs` is `.unlimited`, then the result is always `true`.
        /// Otherwise, this operator compares the demands’ `max` values.
        @inline(__always)
        @inlinable
        public static func < (lhs: Demand, rhs: Demand) -> Bool {
            switch (lhs, rhs) {
            case (.unlimited, .unlimited):
                return false
            case (.unlimited, _):
                return false
            case (_, .unlimited):
                return true
            default:
                return lhs.rawValue < rhs.rawValue
            }
        }

        /// Returns a Boolean value that indicates whether the first demand requests fewer
        /// or the same number of elements as the second.
        /// If both sides are `.unlimited`, the result is always `true`.
        /// If `lhs` is `.unlimited`, then the result is always `false`.
        /// If `rhs` is `.unlimited` then the result is always `true`.
        /// Otherwise, this operator compares the demands’ `max` values.
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

        /// Returns a Boolean that indicates whether the first demand requests more or
        /// the same number of elements as the second.
        /// If both sides are `.unlimited`, the result is always `false`.
        /// If `lhs` is `.unlimited`, then the result is always `true`.
        /// If rhs is `.unlimited` then the result is always `false`.
        /// Otherwise, this operator compares the demands’ `max` values.
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

        /// Returns a Boolean that indicates whether the first demand requests more
        /// elements than the second.
        /// If both sides are `.unlimited`, the result is always `false`.
        /// If `lhs` is `.unlimited`, then the result is always `true`.
        /// If `rhs` is `.unlimited` then the result is always `false`.
        /// Otherwise, this operator compares the demands’ `max` values.
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

        /// Returns a Boolean value indicating whether a demand requests the given number
        /// of elements.
        /// An `.unlimited` demand doesn’t match any integer.
        @inline(__always)
        @inlinable
        public static func == (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return false
            } else {
                return numericCast(lhs.rawValue) == rhs
            }
        }

        /// Returns a Boolean value indicating whether a demand is not equal to
        /// an integer.
        /// The `.unlimited` value isn’t equal to any integer.
        @inlinable
        public static func != (lhs: Demand, rhs: Int) -> Bool {
            if lhs == .unlimited {
                return true
            } else {
                return numericCast(lhs.rawValue) != rhs
            }
        }

        /// Returns a Boolean value indicating whether a given number of elements matches
        /// the request of a given demand.
        /// An `.unlimited` demand doesn’t match any integer.
        @inlinable
        public static func == (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return false
            } else {
                return rhs.rawValue == lhs
            }
        }

        /// Returns a Boolean value indicating whether an integer is not equal to
        /// a demand.
        /// The `.unlimited` value isn’t equal to any integer.
        @inlinable
        public static func != (lhs: Int, rhs: Demand) -> Bool {
            if rhs == .unlimited {
                return true
            } else {
                return Int(rhs.rawValue) != lhs
            }
        }

        /// The number of requested values.
        ///
        /// The value is `nil` if the demand is ``Subscribers/Demand/unlimited``.
        @inlinable public var max: Int? {
            if self == .unlimited {
                return nil
            } else {
                return numericCast(rawValue)
            }
        }

        /// Creates a demand instance from a decoder.
        ///
        /// - Parameter decoder: The decoder of a previously-encoded ``Subscribers/Demand``
        ///   instance.
        public init(from decoder: Decoder) throws {
            try self.init(rawValue: decoder.singleValueContainer().decode(UInt.self))
        }

        /// Encodes the demand to the provided encoder.
        ///
        /// - Parameter encoder: An encoder instance.
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public static func == (lhs: Demand, rhs: Demand) -> Bool {
            return lhs.rawValue == rhs.rawValue
        }
    }
}

#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
extension Subscribers.Demand: Sendable {}
#endif
