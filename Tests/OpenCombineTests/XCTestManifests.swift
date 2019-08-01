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
        testCase(AnyCancellableTests.allTests),
        testCase(AnyPublisherTests.allTests),
        testCase(AssignTests.allTests),
        testCase(CombineIdentifierTests.allTests),
        testCase(CompletionTests.allTests),
        testCase(CurrentValueSubjectTests.allTests),
        testCase(DecodeTests.allTests),
        testCase(DropWhileTests.allTests),
        testCase(EmptyTests.allTests),
        testCase(EncodeTests.allTests),
        testCase(FailTests.allTests),
        testCase(ImmediateSchedulerTests.allTests),
        testCase(JustTests.allTests),
        testCase(MapErrorTests.allTests),
        testCase(MapTests.allTests),
        testCase(MulticastTests.allTests),
        testCase(ResultPublisherTests.allTests),
        testCase(OptionalPublisherTests.allTests),
        testCase(PassthroughSubjectTests.allTests),
        testCase(PrintTests.allTests),
        testCase(PublisherTests.allTests),
        testCase(ReplaceNilTests.allTests),
        testCase(SetFailureTypeTests.allTests),
        testCase(SequenceTests.allTests),
        testCase(SinkTests.allTests),
        testCase(SubscribersDemandTests.allTests),
    ]
}
#endif
