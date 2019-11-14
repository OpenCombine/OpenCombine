//
//  MapKeyPathTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MapKeyPathTests: XCTestCase {

    func testEmpty() {
        MapTests.testEmpty(valueComparator: ==) {
            $0.map(\.doubled)
        }

        MapTests.testEmpty(valueComparator: ==) {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testEmpty(valueComparator: ==) {
            $0.map(\.doubled, \.tripled, \.quadripled)
        }
    }

    func testError() {
        MapTests.testError(valueComparator: ==) {
            $0.map(\.doubled)
        }

        MapTests.testError(valueComparator: ==) {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testError(valueComparator: ==) {
            $0.map(\.doubled, \.tripled, \.quadripled)
        }
    }

    func testRange() {
        MapTests.testRange(valueComparator: ==,
                           mapping: { $0.doubled },
                           { $0.map(\.doubled) })

        MapTests.testRange(valueComparator: ==,
                           mapping: { ($0.doubled, $0.tripled) },
                           { $0.map(\.doubled, \.tripled) })

        MapTests.testRange(valueComparator: ==,
                           mapping: { ($0.doubled, $0.tripled, $0.quadripled) },
                           { $0.map(\.doubled, \.tripled, \.quadripled) })
    }

    func testNoDemand() {
        MapTests.testNoDemand { $0.map(\.doubled) }
        MapTests.testNoDemand { $0.map(\.doubled, \.tripled) }
        MapTests.testNoDemand { $0.map(\.doubled, \.tripled, \.quadripled) }
    }

    func testRequestDemandOnSubscribe() {
        MapTests.testRequestDemandOnSubscribe {
            $0.map(\.doubled)
        }

        MapTests.testRequestDemandOnSubscribe {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testRequestDemandOnSubscribe {
            $0.map(\.doubled, \.tripled, \.quadripled)
        }
    }

    func testDemandOnReceive() {
        MapTests.testDemandOnReceive { $0.map(\.doubled) }
        MapTests.testDemandOnReceive { $0.map(\.doubled, \.tripled) }
        MapTests.testDemandOnReceive { $0.map(\.doubled, \.tripled, \.quadripled) }
    }

    func testCompletion() {
        MapTests.testCompletion(valueComparator: ==) {
            $0.map(\.doubled)
        }

        MapTests.testCompletion(valueComparator: ==) {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testCompletion(valueComparator: ==) {
            $0.map(\.doubled, \.tripled, \.quadripled)
        }
    }

    func testCancel() throws {
        try MapTests.testCancel { $0.map(\.doubled) }
        try MapTests.testCancel { $0.map(\.doubled, \.tripled) }
        try MapTests.testCancel { $0.map(\.doubled, \.tripled, \.quadripled) }
    }

    func testCancelAlreadyCancelled() throws {
        try MapTests.testCancelAldreadyCancelled {
            $0.map(\.doubled)
        }

        try MapTests.testCancelAldreadyCancelled {
            $0.map(\.doubled, \.tripled)
        }

        try MapTests.testCancelAldreadyCancelled {
            $0.map(\.doubled, \.tripled, \.quadripled)
        }
    }

    func testMapKeyPathReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKey",
                           customMirror: expectedChildren(
                               ("keyPath", .contains("KeyPath"))
                           ),
                           playgroundDescription: "ValueForKey",
                           { $0.map(\.doubled) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKeys",
                           customMirror: expectedChildren(
                               ("keyPath0", .contains("KeyPath")),
                               ("keyPath1", .contains("KeyPath"))
                           ),
                           playgroundDescription: "ValueForKeys",
                           { $0.map(\.doubled, \.tripled) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKeys",
                           customMirror: expectedChildren(
                               ("keyPath0", .contains("KeyPath")),
                               ("keyPath1", .contains("KeyPath")),
                               ("keyPath2", .contains("KeyPath"))
                           ),
                           playgroundDescription: "ValueForKeys",
                           { $0.map(\.doubled, \.tripled, \.quadripled) })
    }

    func testMapKeyPathReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.map(\.doubled) })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value((0, 0))],
                                                              demand: .max(42),
                                                              comparator: ==),
                                           { $0.map(\.doubled, \.tripled) })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value((0, 0, 0))],
                                                              demand: .max(42),
                                                              comparator: ==),
                                           { $0.map(\.doubled, \.tripled, \.quadripled) })
    }

    func testMapKeyPathReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.map(\.doubled) }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)], comparator: ==),
            { $0.map(\.doubled, \.tripled) }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)], comparator: ==),
            { $0.map(\.doubled, \.tripled, \.quadripled) }
        )
    }

    func testMapKeyPathLifecycle() throws {
        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map(\.doubled)
        }

        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map(\.doubled, \.tripled)
        }

        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map(\.doubled, \.tripled, \.quadripled)
        }
    }
}

extension Int {
    fileprivate var doubled: Int { return self * 2 }

    fileprivate var tripled: Int { return self * 3 }

    fileprivate var quadripled: Int { return self * 4 }
}
