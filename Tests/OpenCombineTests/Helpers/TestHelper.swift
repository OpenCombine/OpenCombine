//
//  TestHelper.swift
//  
//
//  Created by Joseph Spadafora on 7/6/19.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, *)
class TestHelper<Value: Equatable,
    Failure,
    SourceValue: Equatable,
    SourcePublisher,
    SUT: Publisher>
    where SUT.Failure == Failure,
          SUT.Output == Value,
          SourcePublisher: CustomPublisherBase<SourceValue>
{
    let subscription: CustomSubscription
    let publisher: SourcePublisher
    let tracking: TrackingSubscriberBase<Value, Failure>
    var sut: SUT

    var downstreamSubscription: Subscription?

    init(publisherType: SourcePublisher.Type,
         trackingDemand: Subscribers.Demand = .unlimited,
         receiveValueDemand: Subscribers.Demand = .unlimited,
         customSubscription: CustomSubscription = CustomSubscription(),
         createSut: (SourcePublisher) -> SUT)
    {
        self.subscription = customSubscription
        let createdPublisher = publisherType.init(subscription: customSubscription)
        self.publisher = createdPublisher
        self.sut = createSut(createdPublisher)
        self.tracking = TrackingSubscriberBase<Value, Failure>(
            receiveSubscription: {
                $0.request(trackingDemand)
            },
            receiveValue: { _ in receiveValueDemand }
        )
        tracking.onSubscribe = { self.downstreamSubscription = $0 }
        sut.subscribe(tracking)
    }
}
