//
//  CustomSubscription.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

/// `CustomSubscription` tracks all the requests and cancellations
/// in its `history` property.
///
/// In order to inject `CustomSubscription` into the chain of subscriptions,
/// use the `CustomSubscriber` class.
@available(macOS 10.15, *)
final class CustomSubscription: Subscription {

    enum Event: Equatable {
        case requested(Subscribers.Demand)
        case canceled
    }

    /// The history of requests and cancellations of this subscription.
    private(set) var history: [Event] = []

    private let _requested: ((Subscribers.Demand) -> Void)?
    private let _canceled: (() -> Void)?

    init(onRequest: ((Subscribers.Demand) -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        _requested = onRequest
        _canceled = onCancel
    }

    var lastRequested: Subscribers.Demand? {
        return history.lazy.compactMap {
            switch $0 {
            case .requested(let demand):
                return demand
            case .canceled:
                return nil
            }
        }.last
    }

    var canceled = false

    func request(_ demand: Subscribers.Demand) {
        history.append(.requested(demand))
        _requested?(demand)
    }

    func cancel() {
        history.append(.canceled)
        canceled = true
        _canceled?()
    }
}
