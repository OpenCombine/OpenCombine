//
//  AnySubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

public final class AnySubject<Output, Failure: Error>: Subject {

    private let _box: SubjectBoxBase<Output, Failure>

    public init<SubjectType: Subject>(_ subject: SubjectType)
        where Output == SubjectType.Output, Failure == SubjectType.Failure
    {
        _box = SubjectBox(base: subject)
    }

    public init(
        _ subscribe: @escaping (AnySubscriber<Output, Failure>) -> Void,
        _ send: @escaping (Output) -> Void,
        _ sendCompletion: @escaping (Subscribers.Completion<Failure>) -> Void
    ) {
        _box = ClosureBasedSubject(subscribe, send, sendCompletion)
    }

    public func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Output == SubscriberType.Input, Failure == SubscriberType.Failure
    {
        _box.subscribe(subscriber)
    }

    public func send(_ value: Output) {
        _box.send(value)
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        _box.send(completion: completion)
    }
}

/// A type-erasing base class. Its concrete subclass is generic over the underlying
/// publisher.
private class SubjectBoxBase<Output, Failure: Error>: Subject {

    func send(_ value: Output) {
        fatalError()
    }

    func send(completion: Subscribers.Completion<Failure>) {
        fatalError()
    }

    func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        fatalError()
    }
}

private final class SubjectBox<SubjectType: Subject>
    : SubjectBoxBase<SubjectType.Output,
      SubjectType.Failure> {

    private let base: SubjectType

    init(base: SubjectType) {
        self.base = base
    }

    override func send(_ value: Output) {
        base.send(value)
    }

    override func send(completion: Subscribers.Completion<Failure>) {
        base.send(completion: completion)
    }

    override func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        base.subscribe(subscriber)
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

    override func receive<SubscriberType: Subscriber>(subscriber: SubscriberType)
        where Failure == SubscriberType.Failure, Output == SubscriberType.Input
    {
        _subscribe(AnySubscriber(subscriber))
    }
}
