//
//  CombineIdentifierTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 13.06.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CombineIdentifierTests: XCTestCase {

    func testDefaultInitialized() {
        let id1 = CombineIdentifier()
        let id2 = CombineIdentifier()
        XCTAssertNotEqual(id1,
                          id2,
                          "Default-initialized Combine identifiers must be different")
    }

    func testAnyObject() {

        class Object {}

        let c1 = Object()
        let c2 = Object()

        let id1 = CombineIdentifier(c1)
        let id2 = CombineIdentifier(c2)
        let id3 = CombineIdentifier(c1)

        XCTAssertEqual(id1, id3)
        XCTAssertNotEqual(id1, id2)

        XCTAssertEqual(id1.description,
                       "0x\(String(UInt(bitPattern: ObjectIdentifier(c1)), radix: 16))")
    }

    func testUsesUInt64UnderTheHood() {
        let mirror = Mirror(reflecting: CombineIdentifier())
        XCTAssertEqual(mirror.children.count, 1)
        XCTAssertNotNil(mirror.descendant("rawValue") as? UInt64)
    }
}
