//
//  CombineLatestTests.swift
//
//
//  Created by Kyle on 2023/12/28.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class CombineLatestTests: XCTestCase {
    static let arities = (2...4)

    struct ChildInfo {
        let subscription: CustomSubscription
        let publisher: CustomPublisher
    }

    func testSendsExpectedValues() {
        CombineLatestTests.arities.forEach { arity in
            let (children, combineLatest) = getChildrenAndCombineLatestForArity(arity)

            let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                $0.request(.unlimited)
            })

            combineLatest.subscribe(downstreamSubscriber)

            (0..<arity).forEach { XCTAssertEqual(children[$0].publisher.send(1), .none) }

            XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                          .value(arity)])
        }
    }

    func testChildDemand() {
        [Subscribers.Demand.unlimited, .max(1)].forEach { initialDemand in
            let (children, combineLatest) = getChildrenAndCombineLatestForArity(2)

            var downstreamSubscription: Subscription?
            let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
                receiveSubscription: { downstreamSubscription = $0 })

            combineLatest.subscribe(downstreamSubscriber)

            // Confirm initial demand
            downstreamSubscription?.request(initialDemand)
            (0..<2).forEach { XCTAssertEqual(children[$0].subscription.history,
                                             [.requested(initialDemand)])
            }

            // Confirm no incremental demand
            (0..<2).forEach { XCTAssertEqual(children[$0].publisher.send(1), .max(0)) }

            // Confirm no additional subscription demand
            (0..<2).forEach { XCTAssertEqual(children[$0].subscription.history,
                                             [.requested(initialDemand)])
            }

            // Confirm value was sent
            XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                          .value(2)])

            // Confirm subsequent demand
            downstreamSubscription?.request(.max(2))
            (0..<2).forEach { XCTAssertEqual(children[$0].subscription.history,
                                             [.requested(initialDemand),
                                              .requested(.max(2))])
            }
        }
    }

    func testDownstreamDemandRequestedWhileSendingValue() {
        [Subscribers.Demand.unlimited, .max(10)].forEach { initialDemand in
            let (children, combineLatest) = getChildrenAndCombineLatestForArity(2)
            var downstreamSubscription: Subscription?
            let downstreamSubscriber = TrackingSubscriber(
                receiveSubscription: {
                    downstreamSubscription = $0
                    $0.request(initialDemand)
                },
                receiveValue: { _ in
                    downstreamSubscription?.request(.max(666))
                    return Subscribers.Demand.none
                }
            )

            combineLatest.subscribe(downstreamSubscriber)

            XCTAssertEqual(children[0].publisher.send(1), .none)
            // Apple will use the result of .receive(_ input:) INSTEAD of sending
            // .request to the subscription if a request is received WHILE processing
            // the .receive.
            // AppleRef: 001
            XCTAssertEqual(children[1].publisher.send(1), .max(0))

            XCTAssertEqual(children[0].subscription.history,
                           [.requested(initialDemand),
                            .requested(.max(666))])
            XCTAssertEqual(children[1].subscription.history,
                           [.requested(initialDemand),
                            .requested(.max(666))])
        }
    }

    func testUpstreamValueReceivedWhileSendingValue() {
        let (children, combineLatest) = getChildrenAndCombineLatestForArity(2)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in
                XCTAssertEqual(children[0].publisher.send(1), .none)
                return Subscribers.Demand.none
            }
        )

        combineLatest.subscribe(downstreamSubscriber)

        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[1].publisher.send(1), .none)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(2)])
    }

    func testUpstreamFinishReceivedWhileSendingValue() {
        let (children, combineLatest) = getChildrenAndCombineLatestForArity(2)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in
            children[0].publisher.send(completion: .finished)
                return Subscribers.Demand.none
            }
        )

        combineLatest.subscribe(downstreamSubscriber)

        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[1].publisher.send(1), .none)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(2)])
    }

    func testCombineLatestCompletesOnlyAfterAllChildrenComplete() {
        let upstreamSubscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: upstreamSubscription)
        let child2Publisher = CustomPublisher(subscription: upstreamSubscription)

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        XCTAssertEqual(child1Publisher.send(100), .none)
        XCTAssertEqual(child1Publisher.send(200), .none)
        XCTAssertEqual(child1Publisher.send(300), .none)
        XCTAssertEqual(child2Publisher.send(1), .none)
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(301)])

        XCTAssertEqual(child2Publisher.send(2), .none)
        XCTAssertEqual(child2Publisher.send(3), .none)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(301),
                                                      .value(302),
                                                      .value(303)])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(301),
                                                      .value(302),
                                                      .value(303),
                                                      .completion(.finished)])

        XCTAssertEqual(
            upstreamSubscription.history,
            [.requested(.unlimited), .requested(.unlimited)]
        )
    }

    func testUpstreamExceedsDemand() {
        // Must use CustomPublisher if we want to force send a value beyond the demand
        let child1Subscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: child1Subscription)
        let child2Subscription = CustomSubscription()
        let child2Publisher = CustomPublisher(subscription: child2Subscription)

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            downstreamSubscription = $0
            $0.request(.max(1))
        })

        combineLatest.subscribe(downstreamSubscriber)

        XCTAssertEqual(child1Publisher.send(100), .none)
        XCTAssertEqual(child2Publisher.send(1), .none)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(101)])

        XCTAssertEqual(child1Publisher.send(200), .none)
        XCTAssertEqual(child1Publisher.send(300), .none)
        XCTAssertEqual(child2Publisher.send(2), .none)
        // Surplus is sent downstream despite demand of zero
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(101)])

        XCTAssertEqual(child2Publisher.send(3), .none)
        downstreamSubscription?.request(.max(1))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(101)])
    }

    private func getChildrenAndCombineLatestForArity(_ childCount: Int)
        -> ([ChildInfo], AnyPublisher<Int, TestingError>)
    {
        var children = [ChildInfo]()
        for _ in (0..<childCount) {
            let subscription = CustomSubscription()
            let publisher = CustomPublisher(subscription: subscription)
            children.append(ChildInfo(subscription: subscription,
                                      publisher: publisher))
        }

        let combineLatest: AnyPublisher<Int, TestingError>

        switch childCount {
        case 2:
            combineLatest = AnyPublisher(children[0].publisher.combineLatest(children[1].publisher)
            { $0 + $1 })
        case 3:
            combineLatest = AnyPublisher(children[0].publisher
                .combineLatest(children[1].publisher,
                     children[2].publisher) { $0 + $1 + $2 })
        case 4:
            combineLatest = AnyPublisher(children[0].publisher
                .combineLatest(children[1].publisher,
                     children[2].publisher,
                     children[3].publisher) { $0 + $1 + $2 + $3 })
        default:
            fatalError()
        }

        return (children, combineLatest)
    }

    func testImmediateFinishWhenOneChildFinishesWithNoSurplus() {
        CombineLatestTests.arities.forEach { arity in
            for childToFinish in (0..<arity) {
                let description = "CombineLatest\(arity) childToFinish=\(childToFinish)"
                let (children, combineLatest) = getChildrenAndCombineLatestForArity(arity)
                let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                    $0.request(.unlimited)
                })

                combineLatest.subscribe(downstreamSubscriber)

                children[childToFinish].publisher.send(completion: .finished)
                XCTAssertEqual(
                    downstreamSubscriber.history,
                    [.subscription("CombineLatest")],
                    description
                )
                for child in (0..<arity) {
                    XCTAssertEqual(
                        children[child].subscription.history,
                        [.requested(.unlimited)],
                        description
                    )
                }
            }
        }
    }

    func testDelayedFinishWhenOneChildFinishesWithSurplus() {
        CombineLatestTests.arities.forEach { arity in
            for childToSend in (0..<arity) {
                for childToFinish in (0..<arity) {
                    let (children, combineLatest) = getChildrenAndCombineLatestForArity(arity)

                    let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                        $0.request(.unlimited)
                    })

                    combineLatest.subscribe(downstreamSubscriber)

                    _ = children[childToSend].publisher.send(666)

                    children[childToFinish].publisher.send(completion: .finished)
                    if childToSend == childToFinish {
                        XCTAssertEqual(downstreamSubscriber.history,
                                       [.subscription("CombineLatest")])
                        // Finish the others
                        (0..<arity)
                            .filter { $0 != childToFinish }
                            .forEach( {
                                children[$0].publisher.send(completion: .finished)
                            })

                        XCTAssertEqual(downstreamSubscriber.history,
                                       [.subscription("CombineLatest"),
                                        .completion(.finished)])
                    } else {
                        XCTAssertEqual(downstreamSubscriber.history,
                                       [.subscription("CombineLatest")])
                    }
                }
            }
        }
    }

    func testBCancelledAfterAFailed() {
        let child1Subscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: child1Subscription)

        let child2Subscription = CustomSubscription()
        let child2Publisher = CustomPublisher(subscription: child2Subscription)

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
        })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.failure(.oops))])

        XCTAssertEqual(child1Subscription.history, [.requested(.unlimited)])

        XCTAssertEqual(child2Subscription.history, [.requested(.unlimited),
                                                    .cancelled])
    }

    func testAValueAfterAChildFinishedWithoutSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child1Publisher.send(200)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.finished)])
    }

    func testBValueAfterAChildFinishedWithoutSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.finished)])
    }

    func testAValueAfterAChildFinishedWithSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child1Publisher.send(200)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("CombineLatest"),
            .value(101),
        ])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(101),
                                                      .completion(.finished)])
    }

    func testBValueAfterAChildFinishedWithSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("CombineLatest"),
            .value(101),
        ])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .value(101),
                                                      .completion(.finished)])
    }

    func testValueAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        child1Publisher.send(completion: .failure(.oops))
        child2Publisher.send(1)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.failure(.oops))])
    }

    func testFinishAfterFinished() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .finished)
        child2Publisher.send(completion: .finished)
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.finished)])
    }

    func testFinishAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.failure(.oops))])
    }

    func testFailedAfterFinished() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .finished)
        child2Publisher.send(completion: .finished)
        child1Publisher.send(completion: .failure(.oops))

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.finished)])
    }

    func testFailedAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let combineLatest = child1Publisher.combineLatest(child2Publisher) { $0 + $1 }

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        child1Publisher.send(completion: .failure(.oops))

        XCTAssertEqual(downstreamSubscriber.history, [.subscription("CombineLatest"),
                                                      .completion(.failure(.oops))])
    }

    func testCombineLatest2Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(sendValue: 42,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.combineLatest(child2Publisher) })
    }

    func testCombineLatest3Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(sendValue: 42,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.combineLatest(child2Publisher, child3Publisher) })
    }

    func testCombineLatest4Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(sendValue: 31,
                          cancellingSubscriptionReleasesSubscriber: false,
                          finishingIsPassedThrough: false,
                          { $0.combineLatest(child2Publisher, child3Publisher, child4Publisher) })
    }

    func testCombineLatestReceiveSubscriptionTwice() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        // Can't use `testReceiveSubscriptionTwice` helper here as `(Int, Int)` output
        // can't be made `Equatable`.
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.combineLatest(child2Publisher) }
        )

        XCTAssertEqual(helper.subscription.history, [])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.cancelled, .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)
    }

    func testNoDemandOnSubscriptionCrashes() {
        CombineLatestTests.arities.forEach { arity in
            let (_, combineLatest) = getChildrenAndCombineLatestForArity(arity)

            let downstreamSubscriber = TrackingSubscriber(
                receiveSubscription: { subscription in
                    self.assertCrashes { subscription.request(.none) }
                }
            )

            combineLatest.subscribe(downstreamSubscriber)
        }
    }

    func testCombineLatestCurrentValueSubject() throws {
        let subject = CurrentValueSubject<Void, Never>(())

        let combineLatest = [42].publisher.combineLatest(subject)

        let downstreamSubscriber = TrackingSubscriberBase<(Int, ()), Never>(
            receiveSubscription: { $0.request(.unlimited) })

        combineLatest.subscribe(downstreamSubscriber)

        let history = downstreamSubscriber.history
        XCTAssertEqual(history.count, 2)

        // tuples aren't Equatable, so matching the elements one by one
        switch history[0] {
        case .subscription("CombineLatest"):
          break
        default:
          XCTFail("Failed to match the first subscription event in \(#function)")
        }

        switch history[1] {
        case .value(let v):
            if v.0 != 42 || v.1 != () {
                XCTFail("Failed to match the value event in \(#function)")
            }
        default:
          XCTFail("Failed to match the value event in \(#function)")
        }
    }

    #if !os(WASI)
    func testCombineLatestReferenceIssue() throws {
        var subscriptions: Set<AnyCancellable> = []
        #if OPENCOMBINE_COMPATIBILITY_TEST
        let scheduler = DispatchQueue.main
        #else
        let scheduler = DispatchQueue.OCombine(DispatchQueue.main)
        #endif

        let expectation = self.expectation(description: #function)
        var result: (Int, Int)?

        let firstPublisher = Just(1)
            .delay(for: .milliseconds(600), scheduler: scheduler)
        let secondPublisher = Just(2)
            .delay(for: .milliseconds(600), scheduler: scheduler)
        Publishers.CombineLatest(firstPublisher, secondPublisher)
            .sink(receiveValue: {
                result = ($0.0, $0.1)
                expectation.fulfill()
            })
            .store(in: &subscriptions)

        wait(for: [expectation], timeout: 5)

        XCTAssertEqual(result?.0, 1)
        XCTAssertEqual(result?.1, 2)
    }
    #endif

    func testCombineLatestDocumentationDemo() {
        let pub = PassthroughSubject<Int, Never>()
        let pub2 = PassthroughSubject<Int, Never>()
        let pub3 = PassthroughSubject<Int, Never>()
        let pub4 = PassthroughSubject<Int, Never>()
        let combineLatest = pub
            .combineLatest(pub2, pub3, pub4) { firstValue, secondValue, thirdValue, fourthValue in
                return firstValue * secondValue * thirdValue * fourthValue
            }
        
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) })
        combineLatest.subscribe(downstreamSubscriber)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
            ]
        )
        pub.send(1)
        pub.send(2)
        pub2.send(2)
        pub3.send(9)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
            ]
        )
        pub4.send(1)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
                .value(36), // pub = 2,  pub2 = 2,   pub3 = 9,  pub4 = 1
            ]
        )
        pub.send(3)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
                .value(36), // pub = 2,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(54), // pub = 3,  pub2 = 2,   pub3 = 9,  pub4 = 1
            ]
        )
        pub2.send(12)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
                .value(36), // pub = 2,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(54), // pub = 3,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(324), // pub = 3,  pub2 = 12,  pub3 = 9,  pub4 = 1
            ]
        )
        pub.send(13)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
                .value(36), // pub = 2,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(54), // pub = 3,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(324), // pub = 3,  pub2 = 12,  pub3 = 9,  pub4 = 1
                .value(1404), // pub = 13, pub2 = 12,  pub3 = 9,  pub4 = 1
            ]
        )
        pub3.send(19)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("CombineLatest"),
                .value(36), // pub = 2,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(54), // pub = 3,  pub2 = 2,   pub3 = 9,  pub4 = 1
                .value(324), // pub = 3,  pub2 = 12,  pub3 = 9,  pub4 = 1
                .value(1404), // pub = 13, pub2 = 12,  pub3 = 9,  pub4 = 1
                .value(2964), // pub = 13, pub2 = 12,  pub3 = 19, pub4 = 1
            ]
        )
    }

    func testEquatable() {
        enum E: Equatable {
            case a, b
        }
        let numbersPub = Just(1)
        let lettersPub = Just("A")
        let enumPub = Just(E.a)
        let fractionsPub = Just(1.0)

        let combineLatestNumberLetter = numbersPub.combineLatest(lettersPub)
        XCTAssertEqual(combineLatestNumberLetter, Publishers.CombineLatest(numbersPub, lettersPub))
        XCTAssertNotEqual(combineLatestNumberLetter, Publishers.CombineLatest(numbersPub, Just("B")))

        let combineLatestNumberLetterEnum = numbersPub.combineLatest(lettersPub, enumPub)
        XCTAssertEqual(combineLatestNumberLetterEnum, Publishers.CombineLatest3(numbersPub, lettersPub, enumPub))
        XCTAssertNotEqual(combineLatestNumberLetterEnum, Publishers.CombineLatest3(numbersPub, lettersPub, Just(E.b)))

        let combineLatestNumberLetterEnumFraction = numbersPub.combineLatest(lettersPub, enumPub, fractionsPub)
        XCTAssertEqual(combineLatestNumberLetterEnumFraction, Publishers.CombineLatest4(numbersPub, lettersPub, enumPub, fractionsPub))
        XCTAssertNotEqual(combineLatestNumberLetterEnumFraction, Publishers.CombineLatest4(numbersPub, lettersPub, enumPub, Just(1.5)))
    }
    
    // TODO: The above test case is mostly copied from ZipTests. Optimized for CombineLatest later -
}
