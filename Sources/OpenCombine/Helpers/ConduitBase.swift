//
//  ConduitBase.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.06.2020.
//

internal class ConduitBase<Output, Failure: Error>: Subscription {

    internal init() {}

    internal func offer(_ output: Output) {
        abstractMethod()
    }

    internal func finish(completion: Subscribers.Completion<Failure>) {
        abstractMethod()
    }

    internal func request(_ demand: Subscribers.Demand) {
        abstractMethod()
    }

    internal func cancel() {
        abstractMethod()
    }
}

extension ConduitBase: Equatable {
    internal static func == (lhs: ConduitBase<Output, Failure>,
                             rhs: ConduitBase<Output, Failure>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension ConduitBase: Hashable {
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
