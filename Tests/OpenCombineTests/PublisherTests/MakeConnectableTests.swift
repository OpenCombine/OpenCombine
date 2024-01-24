//
//  MakeConnectableTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 19/09/2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class MakeConnectableTests: XCTestCase {

    // MakeConnectable is just Multicast that uses PassthroughSubject,
    // so we can reuse our existing tests

    func testMulticast() throws {
        try MulticastTests.testGenericMulticast {
            $0.makeConnectable()
        }
    }

    func testMulticastConnectTwice() {
        MulticastTests.testGenericMulticastConnectTwice {
            $0.makeConnectable()
        }
    }

    func testMulticastDisconnect() {
        MulticastTests.testGenericMulticastDisconnect {
            $0.makeConnectable()
        }
    }

    func testReflection() throws {
        try MulticastTests.testGenericMulticastReflection {
            $0.makeConnectable()
        }
    }

    func testMakeConnectableReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(
            value: 0,
            expected: .history([.subscription("Multicast")], demand: .none),
            { $0.makeConnectable() }
        )
    }

    func testMakeConnectableReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.subscription("Multicast")]),
            { $0.makeConnectable() }
        )
    }
}
