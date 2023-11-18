//
//  ViolationsTests.swift
//
//
//  Created by Kyle on 2023/11/18.
//

#if !OPENCOMBINE_COMPATIBILITY_TEST
@testable import OpenCombine
import XCTest

final class ViolationsTests: XCTestCase {
    func testDemandAssertNonZero() {
        let d0 = Subscribers.Demand.none
        let d1 = Subscribers.Demand.max(1)
        let d2 = Subscribers.Demand.unlimited

        assertCrashes {
            d0.assertNonZero()
        }
        d1.assertNonZero()
        d2.assertNonZero()
    }
}
#endif
