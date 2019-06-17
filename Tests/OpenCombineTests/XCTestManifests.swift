//
//  Subscribers.Demand.swift
//
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SubscribersDemandTests.allTests),
        testCase(PassthroughSubjectTests.allTests),
        testCase(CurrentValueSubjectTests.allTests),
        testCase(ImmediateSchedulerTests.allTests),
        testCase(AnySubscriberTests.allTests),
        testCase(AnyPublisherTests.allTests),
        testCase(AnySubjectTests.allTests),
        testCase(CombineIdentifierTests.allTests),
        testCase(AnyCancelableTests.allTests),
        testCase(MulticastTests.allTests),
        testCase(AssignTests.allTests),
        testCase(SinkTests.allTests),
        testCase(DropWhileTests.allTests),
        testCase(EmptyTests.allTests),
        testCase(JustTests.allTests),
        testCase(OnceTests.allTests),
        testCase(PrintTests.allTests),
    ]
}
#endif
