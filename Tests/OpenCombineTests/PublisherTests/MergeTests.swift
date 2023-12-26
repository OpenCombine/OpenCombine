//
//  MergeTests.swift
//
//
//  Created by Kyle on 2023/11/22.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class MergeTests: XCTestCase {
    static let arities = (2 ... 10)

    struct ChildInfo {
        let subscription: CustomSubscription
        let publisher: CustomPublisher
    }

    func testSendsExpectedValues() {
        MergeTests.arities.forEach { arity in
            let (children, merge) = getChildrenAndMergeForArity(arity)
            let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                $0.request(.unlimited)
            })
            merge.subscribe(downstreamSubscriber)
            (0 ..< arity).forEach { XCTAssertEqual(children[$0].publisher.send($0), .none) }
            XCTAssertEqual(
                downstreamSubscriber.history,
                [.subscription("Merge")] + (0 ..< arity).map { .value($0) }
            )
        }
    }

    func testChildDemand() {
        [Subscribers.Demand.unlimited, .max(1), .max(10)].forEach { initialDemand in
            let (children, merge) = getChildrenAndMergeForArity(2)

            var downstreamSubscription: Subscription?
            let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
                receiveSubscription: { downstreamSubscription = $0 })

            merge.subscribe(downstreamSubscriber)

            // Confirm initial demand
            downstreamSubscription?.request(initialDemand)
            (0 ..< 2).forEach {
                if initialDemand == .unlimited {
                    XCTAssertEqual(
                        children[$0].subscription.history,
                        [
                            .requested(.max(1)),
                            .requested(.unlimited),
                        ]
                    )
                } else {
                    XCTAssertEqual(
                        children[$0].subscription.history,
                        [.requested(.max(1))]
                    )
                }
            }
            (0 ..< 2).forEach {
                if initialDemand == .unlimited {
                    XCTAssertEqual(children[$0].publisher.send(1), .max(0))
                } else if initialDemand == .max(1) {
                    switch $0 {
                    case 0: XCTAssertEqual(children[$0].publisher.send(1), .max(1))
                    case 1: XCTAssertEqual(children[$0].publisher.send(1), .max(0))
                    default: break
                    }
                } else if initialDemand == .max(10) {
                    XCTAssertEqual(children[$0].publisher.send(1), .max(1))
                }
            }
            (0 ..< 2).forEach {
                if initialDemand == .unlimited {
                    XCTAssertEqual(
                        children[$0].subscription.history,
                        [
                            .requested(.max(1)),
                            .requested(.unlimited),
                        ]
                    )
                } else {
                    XCTAssertEqual(
                        children[$0].subscription.history,
                        [.requested(.max(1))]
                    )
                }
            }

            if initialDemand == .max(1) {
                XCTAssertEqual(downstreamSubscriber.history, [
                    .subscription("Merge"),
                    .value(1),
                ])
            } else {
                XCTAssertEqual(downstreamSubscriber.history, [
                    .subscription("Merge"),
                    .value(1),
                    .value(1),
                ])
            }

            // Confirm subsequent demand
            downstreamSubscription?.request(.max(2))
            (0 ..< 2).forEach {
                if initialDemand == .unlimited {
                    XCTAssertEqual(children[$0].publisher.send(1), .max(0))
                } else if initialDemand == .max(1) {
                    switch $0 {
                    case 0: XCTAssertEqual(children[$0].publisher.send(1), .max(1))
                    case 1: XCTAssertEqual(children[$0].publisher.send(1), .max(0))
                    default: break
                    }
                } else if initialDemand == .max(10) {
                    XCTAssertEqual(children[$0].publisher.send(1), .max(1))
                }
            }
        }
    }

    func testDownstreamDemandRequestedWhileSendingValue() {
        [Subscribers.Demand.unlimited, .max(1), .max(10)].forEach { initialDemand in
            let (children, merge) = getChildrenAndMergeForArity(2)
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

            merge.subscribe(downstreamSubscriber)

            if initialDemand == .unlimited {
                XCTAssertEqual(children[0].publisher.send(1), .max(0))
                XCTAssertEqual(children[1].publisher.send(1), .max(0))
            } else {
                XCTAssertEqual(children[0].publisher.send(1), .max(1))
                XCTAssertEqual(children[1].publisher.send(1), .max(1))
            }
            
            if initialDemand == .unlimited {
                XCTAssertEqual(children[0].subscription.history, [.requested(.unlimited)])
                XCTAssertEqual(children[1].subscription.history, [.requested(.unlimited)])
            } else {
                XCTAssertEqual(children[0].subscription.history, [.requested(.max(1))])
                XCTAssertEqual(children[1].subscription.history, [.requested(.max(1))])
            }
        }
    }

    func testUpstreamFinishReceivedWhileSendingValue() {
        let (children, merge) = getChildrenAndMergeForArity(2)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) },
            receiveValue: { _ in
                children[0].publisher.send(completion: .finished)
                return .none
            }
        )
        merge.subscribe(downstreamSubscriber)
        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[0].publisher.send(1), .none)
        XCTAssertEqual(children[1].publisher.send(1), .none)
        XCTAssertEqual(
            downstreamSubscriber.history,
            [
                .subscription("Merge"),
                .value(1),
                .value(1),
                .completion(.finished),
                .value(1),
            ]
        )
    }

    func testMergeCompletesOnlyAfterAllChildrenComplete() {
        let upstreamSubscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: upstreamSubscription)
        let child2Publisher = CustomPublisher(subscription: upstreamSubscription)

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriberBase<Int, TestingError>(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        XCTAssertEqual(child1Publisher.send(100), .none)
        XCTAssertEqual(child1Publisher.send(200), .none)
        XCTAssertEqual(child1Publisher.send(300), .none)
        XCTAssertEqual(child2Publisher.send(1), .none)
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(200),
            .value(300),
            .value(1),
        ])
        XCTAssertEqual(child2Publisher.send(2), .none)
        XCTAssertEqual(child2Publisher.send(3), .none)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(200),
            .value(300),
            .value(1),
            .value(2),
            .value(3),
        ])
        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(200),
            .value(300),
            .value(1),
            .value(2),
            .value(3),
            .completion(.finished),
        ])
        XCTAssertEqual(upstreamSubscription.history, [
            .requested(.unlimited),
            .requested(.unlimited),
        ])
    }

    func testUpstreamExceedsDemand() {
        // Must use CustomPublisher if we want to force send a value beyond the demand
        let child1Subscription = CustomSubscription()
        let child1Publisher = CustomPublisher(subscription: child1Subscription)
        let child2Subscription = CustomSubscription()
        let child2Publisher = CustomPublisher(subscription: child2Subscription)

        let merge = child1Publisher.merge(with: child2Publisher)

        var downstreamSubscription: Subscription?
        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            downstreamSubscription = $0
            $0.request(.max(1))
        })

        merge.subscribe(downstreamSubscriber)

        XCTAssertEqual(child1Publisher.send(100), .max(1))
        XCTAssertEqual(child2Publisher.send(1), .none)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])

        XCTAssertEqual(child1Publisher.send(200), .none)
        XCTAssertEqual(child1Publisher.send(300), .none)
        XCTAssertEqual(child2Publisher.send(2), .none)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])

        XCTAssertEqual(child2Publisher.send(3), .none)
        downstreamSubscription?.request(.max(1))
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(300),
        ])
    }

    private func getChildrenAndMergeForArity(_ childCount: Int)
    -> ([ChildInfo], AnyPublisher<Int, TestingError>) {
        var children = [ChildInfo]()
        for _ in 0 ..< childCount {
            let subscription = CustomSubscription()
            let publisher = CustomPublisher(subscription: subscription)
            children.append(ChildInfo(subscription: subscription,
                                      publisher: publisher))
        }

        let merge: AnyPublisher<Int, TestingError>
        switch childCount {
        case let childCount where childCount < 2:
            fatalError("Unsupported child count")
        case 2:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
            )
        case 3:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
                .merge(with: children[2].publisher)
            )
        case 4:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
                .merge(with: children[2].publisher)
                .merge(with: children[3].publisher)
            )
        case 5:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
                .merge(with: children[2].publisher)
                .merge(with: children[3].publisher)
                .merge(with: children[4].publisher)
            )
        case 6:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
                .merge(with: children[2].publisher)
                .merge(with: children[3].publisher)
                .merge(with: children[4].publisher)
                .merge(with: children[5].publisher)
            )
        case 7:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
                .merge(with: children[2].publisher)
                .merge(with: children[3].publisher)
                .merge(with: children[4].publisher)
                .merge(with: children[5].publisher)
                .merge(with: children[6].publisher)
            )
        case 8:
            merge = AnyPublisher(children[0].publisher
                .merge(with: children[1].publisher)
                .merge(with: children[2].publisher)
                .merge(with: children[3].publisher)
                .merge(with: children[4].publisher)
                .merge(with: children[5].publisher)
                .merge(with: children[6].publisher)
                .merge(with: children[7].publisher)
            )
        default:
            merge = AnyPublisher(Publishers.MergeMany(children.map(\.publisher)))
        }
        return (children, merge)
    }

    func testImmediateFinishWhenOneChildFinishesWithNoSurplus() {
        MergeTests.arities.forEach { arity in
            for childToFinish in 0 ..< arity {
                let description = "Merge\(arity) childToFinish=\(childToFinish)"
                let (children, merge) = getChildrenAndMergeForArity(arity)
                let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                    $0.request(.unlimited)
                })
                merge.subscribe(downstreamSubscriber)
                children[childToFinish].publisher.send(completion: .finished)
                XCTAssertEqual(
                    downstreamSubscriber.history,
                    [.subscription("Merge")],
                    description
                )

                for child in 0 ..< arity {
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
        MergeTests.arities.forEach { arity in
            for childToSend in 0 ..< arity {
                for childToFinish in 0 ..< arity {
                    let (children, merge) = getChildrenAndMergeForArity(arity)
                    let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
                        $0.request(.unlimited)
                    })
                    merge.subscribe(downstreamSubscriber)
                    _ = children[childToSend].publisher.send(666)
                    children[childToFinish].publisher.send(completion: .finished)
                    if childToSend == childToFinish {
                        XCTAssertEqual(
                            downstreamSubscriber.history,
                            [
                                .subscription("Merge"),
                                .value(666),
                            ]
                        )
                        // Finish the others
                        (0 ..< arity)
                            .filter { $0 != childToFinish }
                            .forEach {
                                children[$0].publisher.send(completion: .finished)
                            }

                        XCTAssertEqual(
                            downstreamSubscriber.history,
                            [
                                .subscription("Merge"),
                                .value(666),
                                .completion(.finished),
                            ]
                        )
                    } else {
                        XCTAssertEqual(
                            downstreamSubscriber.history,
                            [
                                .subscription("Merge"),
                                .value(666),
                            ]
                        )
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

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(receiveSubscription: {
            $0.request(.unlimited)
        })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge"),
                                                      .completion(.failure(.oops))])

        XCTAssertEqual(child1Subscription.history, [.requested(.unlimited),
                                                    .cancelled])

        XCTAssertEqual(child2Subscription.history, [.requested(.unlimited),
                                                    .cancelled])
    }

    func testAValueAfterAChildFinishedWithoutSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge")])

        child1Publisher.send(200)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(1),
        ])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(1),
            .completion(.finished),
        ])
    }

    func testBValueAfterAChildFinishedWithoutSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge")])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge")])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(1),
        ])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(1),
            .completion(.finished),
        ])
    }

    func testAValueAfterAChildFinishedWithSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])

        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])
        
        child1Publisher.send(200)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])

        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(1),
        ])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(1),
            .completion(.finished),
        ])
    }

    func testBValueAfterAChildFinishedWithSurplus() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])
        
        child1Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
        ])
        
        child2Publisher.send(1)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(1),
        ])

        child2Publisher.send(completion: .finished)
        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .value(1),
            .completion(.finished),
        ])
    }

    func testValueAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(100)
        child1Publisher.send(completion: .failure(.oops))
        child2Publisher.send(1)

        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .value(100),
            .completion(.failure(.oops)),
        ])
    }

    func testFinishAfterFinished() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .finished)
        child2Publisher.send(completion: .finished)
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .completion(.finished),
        ])
    }

    func testFinishAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        child1Publisher.send(completion: .finished)

        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .completion(.failure(.oops)),
        ])
    }

    func testFailedAfterFinished() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .finished)
        child2Publisher.send(completion: .finished)
        child1Publisher.send(completion: .failure(.oops))

        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .completion(.finished),
        ])
    }

    func testFailedAfterFailed() {
        let child1Publisher = PassthroughSubject<Int, TestingError>()
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        let merge = child1Publisher.merge(with: child2Publisher)

        let downstreamSubscriber = TrackingSubscriber(
            receiveSubscription: { $0.request(.unlimited) })

        merge.subscribe(downstreamSubscriber)

        child1Publisher.send(completion: .failure(.oops))
        child1Publisher.send(completion: .failure(.oops))

        XCTAssertEqual(downstreamSubscriber.history, [
            .subscription("Merge"),
            .completion(.failure(.oops)),
        ])
    }

    func testMerge2Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher)
        }
    }

    func testMerge3Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher, child3Publisher)
        }
    }

    func testMerge4Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()

        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher, child3Publisher, child4Publisher)
        }
    }
    
    func testMerge5Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()
        let child5Publisher = PassthroughSubject<Int, TestingError>()

        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher, child3Publisher, child4Publisher, child5Publisher)
        }
    }
    
    func testMerge6Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()
        let child5Publisher = PassthroughSubject<Int, TestingError>()
        let child6Publisher = PassthroughSubject<Int, TestingError>()

        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher, child3Publisher, child4Publisher, child5Publisher, child6Publisher)
        }
    }
    
    func testMerge7Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()
        let child5Publisher = PassthroughSubject<Int, TestingError>()
        let child6Publisher = PassthroughSubject<Int, TestingError>()
        let child7Publisher = PassthroughSubject<Int, TestingError>()

        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher, child3Publisher, child4Publisher, child5Publisher, child6Publisher, child7Publisher)
        }
    }
    
    func testMerge8Lifecycle() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()
        let child3Publisher = PassthroughSubject<Int, TestingError>()
        let child4Publisher = PassthroughSubject<Int, TestingError>()
        let child5Publisher = PassthroughSubject<Int, TestingError>()
        let child6Publisher = PassthroughSubject<Int, TestingError>()
        let child7Publisher = PassthroughSubject<Int, TestingError>()
        let child8Publisher = PassthroughSubject<Int, TestingError>()

        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: child2Publisher, child3Publisher, child4Publisher, child5Publisher, child6Publisher, child7Publisher, child8Publisher)
        }
    }
    
    func testMergeManyLifecycle() throws {
        let childPublisher = PassthroughSubject<Double, TestingError>()

        try testLifecycle(
            sendValue: 42,
            cancellingSubscriptionReleasesSubscriber: false,
            finishingIsPassedThrough: false
        ) {
            $0.merge(with: childPublisher)
        }
    }

    func testMergeReceiveSubscriptionTwice() throws {
        let child2Publisher = PassthroughSubject<Int, TestingError>()

        // Can't use `testReceiveSubscriptionTwice` helper here as `(Int, Int)` output
        // can't be made `Equatable`.
        let helper = OperatorTestHelper(
            publisherType: CustomPublisher.self,
            initialDemand: nil,
            receiveValueDemand: .none,
            createSut: { $0.merge(with: child2Publisher) }
        )

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1))])

        let secondSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: secondSubscription)

        XCTAssertEqual(secondSubscription.history, [.cancelled])

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: helper.subscription)

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled])

        try XCTUnwrap(helper.downstreamSubscription).cancel()

        XCTAssertEqual(helper.subscription.history, [.requested(.max(1)), .cancelled, .cancelled])

        let thirdSubscription = CustomSubscription()

        try XCTUnwrap(helper.publisher.subscriber)
            .receive(subscription: thirdSubscription)
    }

    func testNoDemandOnSubscriptionNoCrashes() {
        MergeTests.arities.forEach { arity in
            let (_, merge) = getChildrenAndMergeForArity(arity)

            let downstreamSubscriber = TrackingSubscriber(
                receiveSubscription: { subscription in
                    subscription.request(.none)
                }
            )
            merge.subscribe(downstreamSubscriber)
        }
    }

    func testIncreasedDemand() throws {
        MergeTests.arities.forEach { arity in
            let (children, merge) = getChildrenAndMergeForArity(arity)
            let downstreamSubscriber = TrackingSubscriber(
                receiveValue: { _ in
                    .max(1)
                }
            )
            merge.subscribe(downstreamSubscriber)

            (0 ..< arity).forEach {
                let demand = children[$0].publisher.send(1)
                if $0 == arity - 1 {
                    XCTAssertEqual(demand, .max(0))
                } else {
                    XCTAssertEqual(demand, .none)
                }
            }
            XCTAssertEqual(downstreamSubscriber.history, [.subscription("Merge")])
        }
    }

    func testMergeCurrentValueSubject() throws {
        let subject = CurrentValueSubject<Int, Never>(0)
        let merge = [42].publisher.merge(with: subject)
        let downstreamSubscriber = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.unlimited) })
        merge.subscribe(downstreamSubscriber)
        let history = downstreamSubscriber.history
        XCTAssertEqual(history, [.subscription("Merge"), .value(42), .value(0)])
    }
}
