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
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

    private struct State {
        var cancelled: Bool
        var history: [Event]
    }

    private let state = Atomic(State(cancelled: false, history: []))

    /// The history of requests and cancellations of this subscription.
    var history: [Event] {
        return state.value.history
    }

    var cancelled: Bool {
        get {
            return state.value.cancelled
        }
        set {
            state.do { state in
                state.cancelled = newValue
            }
        }
    }

    var onRequest: ((Subscribers.Demand) -> Void)?
    var onCancel: (() -> Void)?
    var onDeinit: (() -> Void)?

    init(onRequest: ((Subscribers.Demand) -> Void)? = nil,
         onCancel: (() -> Void)? = nil,
         onDeinit: (() -> Void)? = nil) {
        self.onRequest = onRequest
        self.onCancel = onCancel
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit?()
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

    func request(_ demand: Subscribers.Demand) {
        state.do { state in
            state.history.append(.requested(demand))
        }
        onRequest?(demand)
    }

    func cancel() {
        state.do { state in
            state.history.append(.cancelled)
            state.cancelled = true
        }
        onCancel?()
    }

    var description: String { return "CustomSubscription" }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension CustomSubscription: Equatable {
    static func == (lhs: CustomSubscription, rhs: CustomSubscription) -> Bool {
        return lhs === rhs
    }
}
