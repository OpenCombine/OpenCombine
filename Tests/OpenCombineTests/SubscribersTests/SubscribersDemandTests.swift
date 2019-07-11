//
//  Subscribers.Demand.swift
//
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

// swiftlint:disable identical_operands

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class SubscribersDemandTests: XCTestCase {

    static let allTests = [
        ("testAddition", testAddition),
        ("testSubtraction", testSubtraction),
        ("testMultiplication", testMultiplication),
        ("testComparison", testComparison),
        ("testMax", testMax),
        ("testDescription", testDescription),
        ("testEncodeDecode", testEncodeDecode),
    ]

    func testAddition() {

        XCTAssertEqual(.max(42)   + .unlimited, Subscribers.Demand.unlimited)
        XCTAssertEqual(.unlimited + .unlimited, Subscribers.Demand.unlimited)
        XCTAssertEqual(.unlimited + .max(42), Subscribers.Demand.unlimited)
        XCTAssertEqual(.max(100)  + .max(42), Subscribers.Demand.max(142))

        XCTAssertEqual(.max(81)   + 42, Subscribers.Demand.max(123))
        XCTAssertEqual(.unlimited + 42, Subscribers.Demand.unlimited)

        var demand = Subscribers.Demand.none
        demand += .max(1)
        XCTAssertEqual(demand, .max(1))
        demand += 21
        XCTAssertEqual(demand, .max(22))
        demand += .unlimited
        XCTAssertEqual(demand, .unlimited)
        demand += Int.min
        XCTAssertEqual(demand, .unlimited)
        demand = .max(Int.max)
        XCTAssertEqual(demand + 10, .unlimited)
        demand += 10
        XCTAssertEqual(demand, .unlimited)
    }

    func testSubtraction() {
        XCTAssertEqual(.max(42)   - .unlimited, Subscribers.Demand.max(0))
        XCTAssertEqual(.unlimited - .unlimited, Subscribers.Demand.unlimited)
        XCTAssertEqual(.unlimited - .max(42), Subscribers.Demand.unlimited)
        XCTAssertEqual(.max(100)  - .max(42), Subscribers.Demand.max(58))

        XCTAssertEqual(.max(81)   - 42, Subscribers.Demand.max(39))
        XCTAssertEqual(.unlimited - 42, Subscribers.Demand.unlimited)

        var demand = Subscribers.Demand.max(100)
        demand -= .max(1)
        XCTAssertEqual(demand, .max(99))
        demand -= 21
        XCTAssertEqual(demand, .max(78))
        demand -= .unlimited
        XCTAssertEqual(demand, .max(0))
        demand = .unlimited
        demand -= Int.max
        XCTAssertEqual(demand, .unlimited)
        demand -= .unlimited
        XCTAssertEqual(demand, .unlimited)
        demand = .max(Int.max)
        XCTAssertEqual(demand - (-1), .none)
        demand -= -1
        XCTAssertEqual(demand, .none)
    }

    func testMultiplication() {
        XCTAssertEqual(.max(42)   *  2, Subscribers.Demand.max(84))
        XCTAssertEqual(.unlimited * Int.max, Subscribers.Demand.unlimited)

        var demand = Subscribers.Demand.none
        demand *= 10
        XCTAssertEqual(demand, .none)
        demand = .max(20)
        demand *= 2
        XCTAssertEqual(demand, .max(40))
        demand = .unlimited
        demand *= Int.max
        XCTAssertEqual(demand, .unlimited)
        demand = .max(Int.max)
        XCTAssertEqual(demand * 2, .unlimited)
        demand *= 2
        XCTAssertEqual(demand, .unlimited)
    }

    func testComparison() {
        XCTAssertFalse(Subscribers.Demand.unlimited <  .unlimited)
        XCTAssertFalse(Subscribers.Demand.unlimited >  .unlimited)
        XCTAssertFalse(Subscribers.Demand.unlimited != .unlimited)
        XCTAssertTrue (Subscribers.Demand.unlimited == .unlimited)
        XCTAssertTrue (Subscribers.Demand.unlimited <= .unlimited)
        XCTAssertTrue (Subscribers.Demand.unlimited >= .unlimited)

        XCTAssertFalse(Subscribers.Demand.unlimited <  .max(42))
        XCTAssertTrue (Subscribers.Demand.unlimited >  .max(42))
        XCTAssertTrue (Subscribers.Demand.unlimited != .max(42))
        XCTAssertFalse(Subscribers.Demand.unlimited == .max(42))
        XCTAssertFalse(Subscribers.Demand.unlimited <= .max(42))
        XCTAssertTrue (Subscribers.Demand.unlimited >= .max(42))
        XCTAssertFalse(Subscribers.Demand.unlimited <  42)
        XCTAssertTrue (Subscribers.Demand.unlimited >  42)
        XCTAssertTrue (Subscribers.Demand.unlimited != 42)
        XCTAssertFalse(Subscribers.Demand.unlimited == 42)
        XCTAssertFalse(Subscribers.Demand.unlimited <= 42)
        XCTAssertTrue (Subscribers.Demand.unlimited >= 42)

        XCTAssertTrue (Subscribers.Demand.max(42) <  .unlimited)
        XCTAssertFalse(Subscribers.Demand.max(42) >  .unlimited)
        XCTAssertTrue (Subscribers.Demand.max(42) != .unlimited)
        XCTAssertFalse(Subscribers.Demand.max(42) == .unlimited)
        XCTAssertTrue (Subscribers.Demand.max(42) <= .unlimited)
        XCTAssertFalse(Subscribers.Demand.max(42) >= .unlimited)
        XCTAssertTrue (42 <  Subscribers.Demand.unlimited)
        XCTAssertFalse(42 >  Subscribers.Demand.unlimited)
        XCTAssertTrue (42 != Subscribers.Demand.unlimited)
        XCTAssertFalse(42 == Subscribers.Demand.unlimited)
        XCTAssertTrue (42 <= Subscribers.Demand.unlimited)
        XCTAssertFalse(42 >= Subscribers.Demand.unlimited)

        XCTAssertTrue (Subscribers.Demand.max(42) <  .max(100))
        XCTAssertFalse(Subscribers.Demand.max(42) >  .max(100))
        XCTAssertTrue (Subscribers.Demand.max(42) != .max(100))
        XCTAssertFalse(Subscribers.Demand.max(42) == .max(100))
        XCTAssertTrue (Subscribers.Demand.max(42) <= .max(100))
        XCTAssertFalse(Subscribers.Demand.max(42) >= .max(100))
        XCTAssertTrue (Subscribers.Demand.max(42) <  100)
        XCTAssertFalse(Subscribers.Demand.max(42) >  100)
        XCTAssertTrue (Subscribers.Demand.max(42) != 100)
        XCTAssertFalse(Subscribers.Demand.max(42) == 100)
        XCTAssertTrue (Subscribers.Demand.max(42) <= 100)
        XCTAssertFalse(Subscribers.Demand.max(42) >= 100)
        XCTAssertTrue (42 <  Subscribers.Demand.max(100))
        XCTAssertFalse(42 >  Subscribers.Demand.max(100))
        XCTAssertTrue (42 != Subscribers.Demand.max(100))
        XCTAssertFalse(42 == Subscribers.Demand.max(100))
        XCTAssertTrue (42 <= Subscribers.Demand.max(100))
        XCTAssertFalse(42 >= Subscribers.Demand.max(100))

        XCTAssertFalse(Subscribers.Demand.max(142) <  .max(100))
        XCTAssertTrue (Subscribers.Demand.max(142) >  .max(100))
        XCTAssertTrue (Subscribers.Demand.max(142) != .max(100))
        XCTAssertFalse(Subscribers.Demand.max(142) == .max(100))
        XCTAssertFalse(Subscribers.Demand.max(142) <= .max(100))
        XCTAssertTrue (Subscribers.Demand.max(142) >= .max(100))
        XCTAssertFalse(Subscribers.Demand.max(142) <  100)
        XCTAssertTrue (Subscribers.Demand.max(142) >  100)
        XCTAssertTrue (Subscribers.Demand.max(142) != 100)
        XCTAssertFalse(Subscribers.Demand.max(142) == 100)
        XCTAssertFalse(Subscribers.Demand.max(142) <= 100)
        XCTAssertTrue (Subscribers.Demand.max(142) >= 100)
        XCTAssertFalse(142 <  Subscribers.Demand.max(100))
        XCTAssertTrue (142 >  Subscribers.Demand.max(100))
        XCTAssertTrue (142 != Subscribers.Demand.max(100))
        XCTAssertFalse(142 == Subscribers.Demand.max(100))
        XCTAssertFalse(142 <= Subscribers.Demand.max(100))
        XCTAssertTrue (142 >= Subscribers.Demand.max(100))

        XCTAssertFalse(Subscribers.Demand.max(100) <  .max(100))
        XCTAssertFalse(Subscribers.Demand.max(100) >  .max(100))
        XCTAssertFalse(Subscribers.Demand.max(100) != .max(100))
        XCTAssertTrue (Subscribers.Demand.max(100) == .max(100))
        XCTAssertTrue (Subscribers.Demand.max(100) <= .max(100))
        XCTAssertTrue (Subscribers.Demand.max(100) >= .max(100))
        XCTAssertFalse(Subscribers.Demand.max(100) <  100)
        XCTAssertFalse(Subscribers.Demand.max(100) >  100)
        XCTAssertFalse(Subscribers.Demand.max(100) != 100)
        XCTAssertTrue (Subscribers.Demand.max(100) == 100)
        XCTAssertTrue (Subscribers.Demand.max(100) <= 100)
        XCTAssertTrue (Subscribers.Demand.max(100) >= 100)
        XCTAssertFalse(100 <  Subscribers.Demand.max(100))
        XCTAssertFalse(100 >  Subscribers.Demand.max(100))
        XCTAssertFalse(100 != Subscribers.Demand.max(100))
        XCTAssertTrue (100 == Subscribers.Demand.max(100))
        XCTAssertTrue (100 <= Subscribers.Demand.max(100))
        XCTAssertTrue (100 >= Subscribers.Demand.max(100))
    }

    func testMax() {
        XCTAssertEqual(Subscribers.Demand.none.max, 0)
        XCTAssertEqual(Subscribers.Demand.max(42).max, 42)
        XCTAssertNil(Subscribers.Demand.unlimited.max)
    }

    func testDescription() {
        XCTAssertEqual(Subscribers.Demand.none.description, "max(0)")
        XCTAssertEqual(Subscribers.Demand.max(42).description, "max(42)")
        XCTAssertEqual(Subscribers.Demand.unlimited.description, "unlimited")
    }

    func testEncodeDecode() throws {

        let jsonMax = #"{"rawValue":42}"#
        let jsonUnlimited = #"{"rawValue":\#(UInt(Int.max) + 1)}"#
        let jsonIllFormedNegative = #"{"rawValue":-1}"#
        let jsonIllFormedTooBig = #"{"rawValue":\#(UInt(Int.max) + 2)}"#

        let encodedMax = try JSONEncoder().encode(Subscribers.Demand.max(42))
        XCTAssertEqual(String(decoding: encodedMax, as: UTF8.self), jsonMax)

        let encodedUnlimited = try JSONEncoder().encode(Subscribers.Demand.unlimited)
        XCTAssertEqual(String(decoding: encodedUnlimited, as: UTF8.self), jsonUnlimited)

        let decodedMax = try JSONDecoder().decode(Subscribers.Demand.self,
                                                  from: Data(jsonMax.utf8))
        XCTAssertEqual(decodedMax, .max(42))

        let decodedUnlimited = try JSONDecoder().decode(Subscribers.Demand.self,
                                                        from: Data(jsonUnlimited.utf8))
        XCTAssertEqual(decodedUnlimited, .unlimited)

        XCTAssertThrowsError(
            try JSONDecoder().decode(Subscribers.Demand.self,
                                     from: Data(jsonIllFormedNegative.utf8))
        )

        let decodedIllFormedTooBig = try JSONDecoder()
            .decode(Subscribers.Demand.self, from: Data(jsonIllFormedTooBig.utf8))

        XCTAssertEqual(decodedIllFormedTooBig.description, "max(\(UInt(Int.max) + 2))")
    }
}
