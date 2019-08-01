//
//  OperatorSubscription.swift
//  
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

internal class OperatorSubscription<Downstream: Subscriber>: CustomReflectable {
    internal var downstream: Downstream?
    internal var upstreamSubscription: Subscription?

    internal var customMirror: Mirror {
        return Mirror(self, children: EmptyCollection())
    }

    internal init(downstream: Downstream) {
        self.downstream = downstream
    }

    internal func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
        downstream = nil
    }
}
