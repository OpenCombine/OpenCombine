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

@available(macOS 10.15, *)
final class CustomSubscription: Subscription {

    var requested = Subscribers.Demand.none
    var canceled = false

    func request(_ demand: Subscribers.Demand) {
        requested = demand
    }

    func cancel() {
        canceled = true
    }
}
