//
//  AnySubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public final class AnySubject<Output, Failure: Error>: Subject {

    private let _box: SubjectBoxBase<Output, Failure>

    public init<S: Subject>(_ subject: S) where Output == S.Output, Failure == S.Failure {
        _box = SubjectBox(base: subject)
    }

    public init(
        _ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void,
        _ send: @escaping (Output) -> Void,
        _ sendCompletion: @escaping (Subscribers.Completion<Failure>) -> Void
    ) {
        _box = ClosureBasedSubject(subscribe, send, sendCompletion)
    }

    public func receive<S: Subscriber>(subscriber: S) where Output == S.Input,
                                                            Failure == S.Failure {
        _box.receive(subscriber: subscriber)
    }

    public func send(_ value: Output) {
        _box.send(value)
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        _box.send(completion: completion)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying publisher.
private class SubjectBoxBase<Output, Failure: Error>: Subject {

    func send(_ value: Output) {
        fatalError()
    }

    func send(completion: Subscribers.Completion<Failure>) {
        fatalError()
    }

    func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        fatalError()
    }
}

private final class SubjectBox<S: Subject>: SubjectBoxBase<S.Output, S.Failure> {

    private let base: S

    init(base: S) {
        self.base = base
    }

    override func send(_ value: Output) {
        base.send(value)
    }

    override func send(completion: Subscribers.Completion<Failure>) {
        base.send(completion: completion)
    }

    override func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        base.receive(subscriber: subscriber)
    }
}

private final class ClosureBasedSubject<Output, Failure: Error>
    : SubjectBoxBase<Output, Failure>
{

    private let _subscribe: (AnySubscriber<Output, Failure>) -> Void
    private let _receive: (Output) -> Void
    private let _receiveCompletion: (Subscribers.Completion<Failure>) -> Void

    init(
        _ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void,
        _ receive: @escaping (Output) -> Void,
        _ receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void
    ) {
        _subscribe = subscribe
        _receive = receive
        _receiveCompletion = receiveCompletion
    }

    override func send(_ value: Output) {
        _receive(value)
    }

    override func send(completion: Subscribers.Completion<Failure>) {
        _receiveCompletion(completion)
    }

    override func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        _subscribe(AnySubscriber(subscriber))
    }
}
