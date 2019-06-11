//
//  AnySubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public final class AnySubject<Output, Failure: Error>: Subject {

    private let _subscribe: (AnySubscriber<Output, Failure>) -> Void
    private let _send: (Output) -> Void
    private let _sendCompletion: (Subscribers.Completion<Failure>) -> Void

    public init<S: Subject>(_ subject: S) where Output == S.Output, Failure == S.Failure {
        _subscribe = subject.receive(subscriber:)
        _send = subject.send(_:)
        _sendCompletion = subject.send(completion:)
    }

    public init(
        _ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void,
        _ send: @escaping (Output) -> Void,
        _ sendCompletion: @escaping (Subscribers.Completion<Failure>) -> Void
    ) {
        _subscribe = subscribe
        _send = send
        _sendCompletion = sendCompletion
    }

    public func receive<S: Subscriber>(subscriber: S) where Output == S.Input,
                                                            Failure == S.Failure {
        _subscribe(AnySubscriber(subscriber))
    }

    public func send(_ value: Output) {
        _send(value)
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        _sendCompletion(completion)
    }
}

