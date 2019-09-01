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
        testCase(AnySubscriberTests.allTests),
        testCase(AssignTests.allTests),
        testCase(CombineIdentifierTests.allTests),
        testCase(CompletionTests.allTests),
        testCase(CountTests.allTests),
        testCase(CurrentValueSubjectTests.allTests),
        testCase(DecodeTests.allTests),
        testCase(DeferredTests.allTests),
        testCase(DropWhileTests.allTests),
        testCase(EmptyTests.allTests),
        testCase(EncodeTests.allTests),
        testCase(FailTests.allTests),
        testCase(FilterTests.allTests),
        testCase(FirstTests.allTests),
        testCase(ImmediateSchedulerTests.allTests),
        testCase(IgnoreOutputTests.allTests),
        testCase(JustTests.allTests),
        testCase(MapErrorTests.allTests),
        testCase(MapTests.allTests),
        testCase(MulticastTests.allTests),
        testCase(OptionalPublisherTests.allTests),
        testCase(PassthroughSubjectTests.allTests),
        testCase(PrintTests.allTests),
        testCase(PublisherTests.allTests),
        testCase(ReplaceErrorTests.allTests),
        testCase(ReplaceNilTests.allTests),
        testCase(ResultPublisherTests.allTests),
        testCase(SequenceTests.allTests),
        testCase(SetFailureTypeTests.allTests),
        testCase(SinkTests.allTests),
        testCase(SubscribersDemandTests.allTests),
    ]
}
#endif
