//
//  SubscriptionStatus.swift
//  
//
//  Created by Sergej Jaskiewicz on 21.09.2019.
//

internal enum SubscriptionStatus {
    case awaitingSubscription
    case subscribed(Subscription)
    case pendingTerminal(Subscription)
    case terminal
}

extension SubscriptionStatus {
    internal var isAwaitingSubscription: Bool {
        switch self {
        case .awaitingSubscription:
            return true
        default:
            return false
        }
    }

    internal var subscription: Subscription? {
        switch self {
        case .awaitingSubscription, .terminal:
            return nil
        case let .subscribed(subscription), let .pendingTerminal(subscription):
            return subscription
        }
    }
}
