//
//  OperatorTestHelper.swift
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

/// `OperatorTestHelper` is an abstraction that helps avoid a lot of boilerplate when
/// testing an operator.  It is initialized with a publisher type and creates a
/// `CustomSubscription`, `CustomPublisherBase` and `TrackingSubscriberBase`.
@available(macOS 10.15, iOS 13.0, *)
class OperatorTestHelper<SourceValue: Equatable,
                         SourcePublisher,
                         Sut: Publisher>
    where Sut.Output: Equatable,
          SourcePublisher: CustomPublisherBase<SourceValue, TestingError>
{
    typealias Value = Sut.Output
    typealias Failure = Sut.Failure

    let subscription: CustomSubscription
    let publisher: SourcePublisher
    let tracking: TrackingSubscriberBase<Value, Failure>
    private(set) var sut: Sut

    var downstreamSubscription: Subscription?

    /// This initializes the `OperatorTestHelper`.  In most cases,
    /// you can just pass a `publisherType` and closure
    /// for `createSut` to get all the setup that you'll need for a test.
    /// - Parameter publisherType: This should be filled in with the
    ///   type of `CustomPublisherBase` that you would like the
    ///   operator you are testing to be built from.
    /// - Parameter initialDemand: This is the demand that the
    ///   created `TrackingSubscriber` should return upon receiving a subscription.
    /// - Parameter receiveValueDemand: This is the demand that the
    ///   created `TrackingSubscriber should return upon receiving a value.
    /// - Parameter customSubscription: This parameter defaults to `CustomSubscription()`,
    ///   but can be replaced with your own instance if you want to override
    ///   any of the default `CustomSubscription` initializer closures.
    /// - Parameter createSut: This closure takes a new concrete instance
    ///   of the `publisherType` as an input to the closure and creates an
    ///   instance of the operator that you are trying to test.
    init(publisherType: SourcePublisher.Type,
         initialDemand: Subscribers.Demand?,
         receiveValueDemand: Subscribers.Demand,
         customSubscription: CustomSubscription = CustomSubscription(),
         createSut: (SourcePublisher) -> Sut)
    {
        self.subscription = customSubscription
        let createdPublisher = publisherType.init(subscription: customSubscription)
        self.publisher = createdPublisher
        self.sut = createSut(createdPublisher)
        self.tracking = TrackingSubscriberBase<Value, Failure>(
            receiveSubscription: {
                initialDemand.map($0.request)
            },
            receiveValue: { _ in receiveValueDemand }
        )
        tracking.onSubscribe = { self.downstreamSubscription = $0 }
        sut.subscribe(tracking)
    }
}
