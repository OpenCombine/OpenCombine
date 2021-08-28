//
//  Future.swift
//  
//
//  Created by Max Desiatov on 24/11/2019.
//

/// A publisher that eventually produces a single value and then finishes or fails.
public final class Future<Output, Failure: Error>: Publisher {

    /// A type that represents a closure to invoke in the future, when an element or error
    /// is available.
    ///
    /// The promise closure receives one parameter: a `Result` that contains either
    /// a single element published by a `Future`, or an error.
    public typealias Promise = (Result<Output, Failure>) -> Void

    private let lock = UnfairLock.allocate()

    private var downstreams = ConduitList<Output, Failure>.empty

    private var result: Result<Output, Failure>?

    /// Creates a publisher that invokes a promise closure when the publisher emits
    /// an element.
    ///
    /// - Parameter attemptToFulfill: A `Promise` that the publisher invokes when
    ///   the publisher emits an element or terminates with an error.
    public init(
        _ attemptToFulfill: @escaping (@escaping Promise) -> Void
    ) {
        attemptToFulfill(self.promise)
    }

    deinit {
        lock.deallocate()
    }

    private func promise(_ result: Result<Output, Failure>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let downstreams = self.downstreams.take()
        lock.unlock()
        switch result {
        case .success(let output):
            downstreams.forEach { $0.offer(output) }
        case .failure(let error):
            downstreams.forEach { $0.finish(completion: .failure(error)) }
        }
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        let conduit = Conduit(parent: self, downstream: subscriber)
        lock.lock()
        if let result = self.result {
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
            conduit.fulfill(result)
        } else {
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
        }
    }

    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        lock.lock()
        downstreams.remove(conduit)
        lock.unlock()
    }
}

extension Future {

    private final class Conduit<Downstream: Subscriber>
        : ConduitBase<Output, Failure>,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Output, Downstream.Failure == Failure
    {

        fileprivate var parent: Future?

        fileprivate var downstream: Downstream?

        fileprivate var hasAnyDemand = false

        private var lock = UnfairLock.allocate()

        private var downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate init(parent: Future, downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        fileprivate func fulfill(_ result: Result<Output, Failure>) {
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            let parent = self.parent
            if case .success = result, !hasAnyDemand {
                lock.unlock()
                return
            }
            self.downstream = nil
            self.parent = nil
            lock.unlock()
            downstreamLock.lock()
            switch result {
            case .success(let output):
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(error))
            }
            downstreamLock.unlock()
            parent?.disassociate(self)
        }

        override func offer(_ output: Output) {
            fulfill(.success(output))
        }

        override func finish(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                assertionFailure("unreachable")
            case .failure(let error):
                fulfill(.failure(error))
            }
        }

        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream, let parent = self.parent else {
                lock.unlock()
                return
            }
            hasAnyDemand = true

            parent.lock.lock()
            guard let result = parent.result else {
                parent.lock.unlock()
                lock.unlock()
                return
            }
            parent.lock.unlock()
            self.downstream = nil
            self.parent = nil
            lock.unlock()
            downstreamLock.lock()
            switch result {
            case .success(let output):
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
            case .failure(let error):
                // This branch is not reachable under normal circumstances,
                // but may be reachable in case of a race condition.
                downstream.receive(completion: .failure(error))
            }
            downstreamLock.unlock()
            parent.disassociate(self)
        }

        override func cancel() {
            lock.lock()
            if downstream.take() == nil {
                lock.unlock()
                return
            }
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
        }

        var description: String { return "Future" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("parent", parent as Any),
                ("downstream", downstream as Any),
                ("hasAnyDemand", hasAnyDemand),
                ("subject", parent as Any)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
