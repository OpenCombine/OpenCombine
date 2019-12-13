//
//  URLSession.swift
//  
//
//  Created by Sergej Jaskiewicz on 13.12.2019.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import OpenCombine

extension URLSession {

    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `URLSession` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `URLSession.DataTaskPublisher`,
    /// because Swift is unable to understand which `DataTaskPublisher`
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `URLSession.OCombine.DataTaskPublisher`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public struct OCombine {

        public let session: URLSession

        public init(_ session: URLSession) {
            self.session = session
        }

        public struct DataTaskPublisher: Publisher {

            public typealias Output = (data: Data, response: URLResponse)

            public typealias Failure = URLError

            public let request: URLRequest

            public let session: URLSession

            public init(request: URLRequest, session: URLSession) {
                self.request = request
                self.session = session
            }

            public func receive<Downstream: Subscriber>(subscriber: Downstream)
                where Downstream.Failure == Failure, Downstream.Input == Output
            {
                let subscription = Inner(parent: self, downstream: subscriber)
                subscriber.receive(subscription: subscription)
            }
        }

        /// Returns a publisher that wraps a URL session data task for a given URL.
        ///
        /// The publisher publishes data when the task completes, or terminates if
        /// the task fails with an error.
        ///
        /// - Parameter url: The URL for which to create a data task.
        /// - Returns: A publisher that wraps a data task for the URL.
        public func dataTaskPublisher(for url: URL) -> DataTaskPublisher {
            return dataTaskPublisher(for: URLRequest(url: url))
        }

        /// Returns a publisher that wraps a URL session data task for a given
        /// URL request.
        ///
        /// The publisher publishes data when the task completes, or terminates if
        /// the task fails with an error.
        ///
        /// - Parameter request: The URL request for which to create a data task.
        /// - Returns: A publisher that wraps a data task for the URL request.
        public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher {
            return .init(request: request, session: session)
        }
    }

#if !canImport(Combine)
    public typealias DataTaskPublisher = OCombine.DataTaskPublisher
#endif
}

extension URLSession {

    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `URLSession` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `URLSession.shared.dataTaskPublisher(for: url)`,
    /// because Swift is unable to understand which `dataTaskPublisher` method
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `URLSession.shared.ocombine.dataTaskPublisher(for: url)`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public var ocombine: OCombine { return .init(self) }

#if !canImport(Combine)
    /// Returns a publisher that wraps a URL session data task for a given URL.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task
    /// fails with an error.
    ///
    /// - Parameter url: The URL for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL.
    public func dataTaskPublisher(for url: URL) -> DataTaskPublisher {
        return ocombine.dataTaskPublisher(for: url)
    }

    /// Returns a publisher that wraps a URL session data task for a given URL request.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task
    /// fails with an error.
    ///
    /// - Parameter request: The URL request for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL request.
    public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher {
        return ocombine.dataTaskPublisher(for: request)
    }
#endif
}

extension URLSession.OCombine.DataTaskPublisher {
    private class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == (data: Data, response: URLResponse),
              Downstream.Failure == URLError
    {
        private let lock = UnfairLock.allocate()

        private var parent: URLSession.OCombine.DataTaskPublisher?

        private var downstream: Downstream?

        private var demand = Subscribers.Demand.none

        private var task: URLSessionDataTask?

        fileprivate init(parent: URLSession.OCombine.DataTaskPublisher,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }

        deinit {
            lock.deallocate()
        }

        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let parent = self.parent else {
                lock.unlock()
                return
            }
            if self.task == nil {
                task = parent.session.dataTask(with: parent.request,
                                               completionHandler: handleResponse)
            }
            self.demand += demand
            let task = self.task
            lock.unlock()
            task?.resume()
        }

        private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
            lock.lock()
            guard demand > 0, parent != nil, let downstream = self.downstream else {
                lock.unlock()
                return
            }
            lockedTerminate()
            lock.unlock()
            switch (data, response, error) {
            case let (data, response?, nil):
                _ = downstream.receive((data ?? Data(), response))
                downstream.receive(completion: .finished)
            case let (_, _, error as URLError):
                downstream.receive(completion: .failure(error))
            default:
                downstream.receive(completion: .failure(URLError(.unknown)))
            }
        }

        func cancel() {
            lock.lock()
            guard parent != nil else {
                lock.unlock()
                return
            }
            let task = self.task
            lockedTerminate()
            lock.unlock()
            task?.cancel()
        }

        private func lockedTerminate() {
            parent = nil
            downstream = nil
            demand = .none
            task = nil
        }

        var description: String { return "DataTaskPublisher" }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("task", task as Any),
                ("downstream", downstream as Any),
                ("parent", parent as Any),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }
    }
}
