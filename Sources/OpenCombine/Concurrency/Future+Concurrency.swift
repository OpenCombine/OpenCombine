//
//  Future+Concurrency.swift
//
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
extension Future where Failure == Never {

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var value: Output {
        get async {
            await ContinuationSubscriber.withUnsafeSubscription(self)
        }
    }
}

extension Future {

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var value: Output {
        get async throws {
            try await ContinuationSubscriber.withUnsafeThrowingSubscription(self)
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private final class ContinuationSubscriber<Input,
                                           UpstreamFailure: Error,
                                           ErrorOrNever: Error>
    : Subscriber
{
    typealias Failure = UpstreamFailure

    private var continuation: UnsafeContinuation<Input, ErrorOrNever>?
    private var subscription: Subscription?
    private let lock = UnfairLock.allocate()

    private init(_ continuation: UnsafeContinuation<Input, ErrorOrNever>) {
        self.continuation = continuation
    }

    deinit {
        lock.deallocate()
    }

    func receive(subscription: Subscription) {
        lock.lock()
        guard self.subscription == nil else {
            assertionFailure("Unexpected state: received subscription twice")
            lock.unlock()
            subscription.cancel()
            return
        }
        self.subscription = subscription
        lock.unlock()
        subscription.request(.max(1))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        if let continuation = self.continuation.take() {
            lock.unlock()
            continuation.resume(returning: input)
        } else {
            assertionFailure("Unexpected state: already completed")
            lock.unlock()
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        subscription = nil
        lock.unlock()
        completion.failure.map(handleFailure)
    }

    private func handleFailure(_ error: Failure) {
        lock.lock()
        if let continuation = self.continuation.take() {
            lock.unlock()
            continuation.resume(throwing: error as! ErrorOrNever)
        } else {
            assertionFailure("Unexpected state: already completed")
            lock.unlock()
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension ContinuationSubscriber where ErrorOrNever == Error {
    fileprivate static func withUnsafeThrowingSubscription<Upstream: Publisher>(
        _ upstream: Upstream
    ) async throws -> Input
        where Upstream.Output == Input,
              Upstream.Failure == UpstreamFailure
    {
        try await withUnsafeThrowingContinuation { continuation in
            upstream.subscribe(ContinuationSubscriber(continuation))
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension ContinuationSubscriber where UpstreamFailure == Never, ErrorOrNever == Never {
    fileprivate static func withUnsafeSubscription<Upstream: Publisher>(
        _ upstream: Upstream
    ) async -> Input
        where Upstream.Output == Input,
              Upstream.Failure == Never
    {
        await withUnsafeContinuation { continuation in
            upstream.subscribe(ContinuationSubscriber(continuation))
        }
    }
}

#endif
