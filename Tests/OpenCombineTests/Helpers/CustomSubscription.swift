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
@available(macOS 10.15, iOS 13.0, *)
final class CustomSubscription: Subscription, CustomStringConvertible {

    enum Event: Equatable, CustomStringConvertible {
        case requested(Subscribers.Demand)
        case cancelled

        var description: String {
            switch self {
            case .requested(let demand):
                return ".requested(.\(demand))"
            case .cancelled:
                return ".cancelled"
            }
        }
    }

    /// The history of requests and cancellations of this subscription.
    private(set) var history: [Event] = []

    private let _requested: ((Subscribers.Demand) -> Void)?
    private let _cancelled: (() -> Void)?

    init(onRequest: ((Subscribers.Demand) -> Void)? = nil,
         onCancel: (() -> Void)? = nil) {
        _requested = onRequest
        _cancelled = onCancel
    }

    var lastRequested: Subscribers.Demand? {
        return history.lazy.compactMap {
            switch $0 {
            case .requested(let demand):
                return demand
            case .cancelled:
                return nil
            }
        }.last
    }

    var cancelled = false

    func request(_ demand: Subscribers.Demand) {
        history.append(.requested(demand))
        _requested?(demand)
    }

    func cancel() {
        history.append(.cancelled)
        cancelled = true
        _cancelled?()
    }

    var description: String { return "CustomSubscription" }
}
