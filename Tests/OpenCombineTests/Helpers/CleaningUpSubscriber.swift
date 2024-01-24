//
//  CleaningUpSubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.10.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class CleaningUpSubscriber<Input, Failure: Error>: Subscriber {

    private(set) var subscription: Subscription?

    private let onDeinit: () -> Void

    init(onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit()
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        subscription = nil
    }
}
