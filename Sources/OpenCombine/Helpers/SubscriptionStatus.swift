//
//  SubscriptionStatus.swift
//  
//
//  Created by Sergej Jaskiewicz on 21.09.2019.
//

internal enum SubscriptionStatus {
    case awaitingSubscription
    case subscribed(Subscription)
    case terminal
}

extension SubscriptionStatus {
    internal var isAwaigingSubscription: Bool {
        switch self {
        case .awaitingSubscription:
            return true
        default:
            return false
        }
    }
}
