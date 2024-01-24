//
//  Publishers.CombineLatest.swift
//  OpenCombine
//
//  Created by Kyle on 2023/12/27.
//  Audited for 2023 Release

// MARK: - combineLatest methods on Publisher

extension Publisher {
    /// Subscribes to an additional publisher and publishes a tuple upon receiving output from either publisher.
    ///
    /// Use ``Publisher/combineLatest(_:)`` when you want the downstream subscriber to receive a tuple of the most-recent element from multiple publishers when any of them emit a value. To pair elements from multiple publishers, use ``Publisher/zip(_:)`` instead. To receive just the most-recent element from multiple publishers rather than tuples, use ``Publisher/merge(with:)-394v9``.
    ///
    /// > Tip: The combined publisher doesn't produce elements until each of its upstream publishers publishes at least one element.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t ``Subscribers/Demand/unlimited``, it drops values from upstream publishers. It implements this by using a buffer size of 1 for each upstream, and holds the most-recent value in each buffer.
    ///
    /// In this example, ``PassthroughSubject`` `pub1` and also `pub2` emit values; as ``Publisher/combineLatest(_:)`` receives input from either upstream publisher, it combines the latest value from each publisher into a tuple and publishes it.
    ///
    ///     let pub1 = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pub1
    ///         .combineLatest(pub2)
    ///         .sink { print("Result: \($0).") }
    ///
    ///     pub1.send(1)
    ///     pub1.send(2)
    ///     pub2.send(2)
    ///     pub1.send(3)
    ///     pub1.send(45)
    ///     pub2.send(22)
    ///
    ///     // Prints:
    ///     //    Result: (2, 2).    // pub1 latest = 2, pub2 latest = 2
    ///     //    Result: (3, 2).    // pub1 latest = 3, pub2 latest = 2
    ///     //    Result: (45, 2).   // pub1 latest = 45, pub2 latest = 2
    ///     //    Result: (45, 22).  // pub1 latest = 45, pub2 latest = 22
    ///
    /// When all upstream publishers finish, this publisher finishes. If an upstream publisher never publishes a value, this publisher never finishes.
    ///
    /// - Parameter other: Another publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this and another publisher.
    public func combineLatest<P>(_ other: P) -> Publishers.CombineLatest<Self, P> where P: Publisher, Self.Failure == P.Failure {
        Publishers.CombineLatest(self, other)
    }
    
    /// Subscribes to an additional publisher and invokes a closure upon receiving output from either publisher.
    ///
    /// Use `combineLatest<P,T>(_:)` to combine the current and one additional publisher and transform them using a closure you specify to publish a new value to the downstream.
    ///
    /// > Tip: The combined publisher doesn't produce elements until each of its upstream publishers publishes at least one element.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size of 1 for each upstream, and holds the most-recent value in each buffer.
    ///
    /// In the example below, `combineLatest()` receives the most-recent values published by the two publishers, it multiplies them together, and republishes the result:
    ///
    ///     let pub1 = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pub1
    ///         .combineLatest(pub2) { (first, second) in
    ///             return first * second
    ///         }
    ///         .sink { print("Result: \($0).") }
    ///
    ///     pub1.send(1)
    ///     pub1.send(2)
    ///     pub2.send(2)
    ///     pub1.send(9)
    ///     pub1.send(3)
    ///     pub2.send(12)
    ///     pub1.send(13)
    ///     //
    ///     // Prints:
    ///     //Result: 4.    (pub1 latest = 2, pub2 latest = 2)
    ///     //Result: 18.   (pub1 latest = 9, pub2 latest = 2)
    ///     //Result: 6.    (pub1 latest = 3, pub2 latest = 2)
    ///     //Result: 36.   (pub1 latest = 3, pub2 latest = 12)
    ///     //Result: 156.  (pub1 latest = 13, pub2 latest = 12)
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - other: Another publisher to combine with this one.
    ///   - transform: A closure that receives the most-recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this and another publisher.
    public func combineLatest<P, T>(_ other: P, _ transform: @escaping (Self.Output, P.Output) -> T) -> Publishers.Map<Publishers.CombineLatest<Self, P>, T> where P: Publisher, Self.Failure == P.Failure {
        Publishers.CombineLatest(self, other).map(transform)
    }

    /// Subscribes to two additional publishers and publishes a tuple upon receiving output from any of the publishers.
    ///
    /// Use ``Publisher/combineLatest(_:_:)-81vgd`` when you want the downstream subscriber to receive a tuple of the most-recent element from multiple publishers when any of them emit a value. To combine elements from multiple publishers, use ``Publisher/zip(_:_:)-2p498`` instead. To receive just the most-recent element from multiple publishers rather than tuples, use ``Publisher/merge(with:_:)``.
    ///
    /// > Tip: The combined publisher doesn't produce elements until each of its upstream publishers publishes at least one element.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t ``Subscribers/Demand/unlimited``, it drops values from upstream publishers. It implements this by using a buffer size of 1 for each upstream, and holds the most-recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never publishes a value, this publisher never finishes.
    ///
    /// In this example, three instances of ``PassthroughSubject`` emit values; as ``Publisher/combineLatest(_:_:)-81vgd`` receives input from any of the upstream publishers, it combines the latest value from each publisher into a tuple and publishes it:
    ///
    ///     let pub = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///     let pub3 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pub
    ///         .combineLatest(pub2, pub3)
    ///         .sink { print("Result: \($0).") }
    ///
    ///     pub.send(1)
    ///     pub.send(2)
    ///     pub2.send(2)
    ///     pub3.send(9)
    ///
    ///     pub.send(3)
    ///     pub2.send(12)
    ///     pub.send(13)
    ///     pub3.send(19)
    ///
    ///     // Prints:
    ///     //  Result: (2, 2, 9).
    ///     //  Result: (3, 2, 9).
    ///     //  Result: (3, 12, 9).
    ///     //  Result: (13, 12, 9).
    ///     //  Result: (13, 12, 19).
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with the first publisher.
    ///   - publisher2: A third publisher to combine with the first publisher.
    /// - Returns: A publisher that receives and combines elements from this publisher and two other publishers.
    public func combineLatest<P, Q>(_ publisher1: P, _ publisher2: Q) -> Publishers.CombineLatest3<Self, P, Q> where P: Publisher, Q: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure {
        Publishers.CombineLatest3(self, publisher1, publisher2)
    }

    /// Subscribes to two additional publishers and invokes a closure upon receiving output from any of the publishers.
    ///
    /// Use `combineLatest<P, Q>(_:,_:)` to combine the current and two additional publishers and transform them using a closure you specify to publish a new value to the downstream.
    ///
    /// > Tip: The combined publisher doesn't produce elements until each of its upstream publishers publishes at least one element.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size of 1 for each upstream, and holds the most-recent value in each buffer.
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never publishes a value, this publisher never finishes.
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// In the example below, `combineLatest()` receives the most-recent values published by three publishers, multiplies them together, and republishes the result:
    ///
    ///     let pub = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///     let pub3 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pub
    ///         .combineLatest(pub2, pub3) { firstValue, secondValue, thirdValue in
    ///             return firstValue * secondValue * thirdValue
    ///         }
    ///         .sink { print("Result: \($0).") }
    ///
    ///     pub.send(1)
    ///     pub.send(2)
    ///     pub2.send(2)
    ///     pub3.send(10)
    ///
    ///     pub.send(9)
    ///     pub3.send(4)
    ///     pub2.send(12)
    ///
    ///     // Prints:
    ///     //  Result: 40.     // pub = 2, pub2 = 2, pub3 = 10
    ///     //  Result: 180.    // pub = 9, pub2 = 2, pub3 = 10
    ///     //  Result: 72.     // pub = 9, pub2 = 2, pub3 = 4
    ///     //  Result: 432.    // pub = 9, pub2 = 12, pub3 = 4
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with the first publisher.
    ///   - publisher2: A third publisher to combine with the first publisher.
    ///   - transform: A closure that receives the most-recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this publisher and two other publishers.
    public func combineLatest<P, Q, T>(_ publisher1: P, _ publisher2: Q, _ transform: @escaping (Self.Output, P.Output, Q.Output) -> T) -> Publishers.Map<Publishers.CombineLatest3<Self, P, Q>, T> where P: Publisher, Q: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure {
        Publishers.CombineLatest3(self, publisher1, publisher2).map(transform)
    }

    /// Subscribes to three additional publishers and publishes a tuple upon receiving output from any of the publishers.
    ///
    /// Use ``Publisher/combineLatest(_:_:_:)-7mt86`` when you want the downstream subscriber to receive a tuple of the most-recent element from multiple publishers when any of them emit a value. To combine elements from multiple publishers, use ``Publisher/zip(_:_:_:)-67czn`` instead. To receive just the most-recent element from multiple publishers rather than tuples, use ``Publisher/merge(with:_:_:)``.
    ///
    /// > Tip: The combined publisher doesn't produce elements until each of its upstream publishers publishes at least one element.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t ``Subscribers/Demand/unlimited``, it drops values from upstream publishers. It implements this by using a buffer size of 1 for each upstream, and holds the most-recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never publishes a value, this publisher never finishes.
    ///
    /// In the example below, ``Publisher/combineLatest(_:_:_:)-7mt86`` receives input from any of the publishers, combines the latest value from each publisher into a tuple and publishes it:
    ///
    ///     let pub = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///     let pub3 = PassthroughSubject<Int, Never>()
    ///     let pub4 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pub
    ///         .combineLatest(pub2, pub3, pub4)
    ///         .sink { print("Result: \($0).") }
    ///
    ///     pub.send(1)
    ///     pub.send(2)
    ///     pub2.send(2)
    ///     pub3.send(9)
    ///     pub4.send(1)
    ///
    ///     pub.send(3)
    ///     pub2.send(12)
    ///     pub.send(13)
    ///     pub3.send(19)
    ///     //
    ///     // Prints:
    ///     //  Result: (2, 2, 9, 1).
    ///     //  Result: (3, 2, 9, 1).
    ///     //  Result: (3, 12, 9, 1).
    ///     //  Result: (13, 12, 9, 1).
    ///     //  Result: (13, 12, 19, 1).
    ///
    /// If any individual publisher of the combined set terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with the first publisher.
    ///   - publisher2: A third publisher to combine with the first publisher.
    ///   - publisher3: A fourth publisher to combine with the first publisher.
    /// - Returns: A publisher that receives and combines elements from this publisher and three other publishers.
    public func combineLatest<P, Q, R>(_ publisher1: P, _ publisher2: Q, _ publisher3: R) -> Publishers.CombineLatest4<Self, P, Q, R> where P: Publisher, Q: Publisher, R: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        Publishers.CombineLatest4(self, publisher1, publisher2, publisher3)
    }

    /// Subscribes to three additional publishers and invokes a closure upon receiving output from any of the publishers.
    ///
    /// Use ``Publisher/combineLatest(_:_:_:_:)`` when you need to combine the current and 3 additional publishers and transform the values using a closure in which you specify the published elements, to publish a new element.
    ///
    /// > Tip: The combined publisher doesn't produce elements until each of its upstream publishers publishes at least one element.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t ``Subscribers/Demand/unlimited``, it drops values from upstream publishers. It implements this by using a buffer size of 1 for each upstream, and holds the most-recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never publishes a value, this publisher never finishes.
    ///
    /// In the example below, as ``Publisher/combineLatest(_:_:_:_:)`` receives the most-recent values published by four publishers, multiplies them together, and republishes the result:
    ///
    ///     let pub = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///     let pub3 = PassthroughSubject<Int, Never>()
    ///     let pub4 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pub
    ///         .combineLatest(pub2, pub3, pub4) { firstValue, secondValue, thirdValue, fourthValue in
    ///             return firstValue * secondValue * thirdValue * fourthValue
    ///         }
    ///         .sink { print("Result: \($0).") }
    ///
    ///     pub.send(1)
    ///     pub.send(2)
    ///     pub2.send(2)
    ///     pub3.send(9)
    ///     pub4.send(1)
    ///
    ///     pub.send(3)
    ///     pub2.send(12)
    ///     pub.send(13)
    ///     pub3.send(19)
    ///
    ///     // Prints:
    ///     //  Result: 36.     // pub = 2,  pub2 = 2,   pub3 = 9,  pub4 = 1
    ///     //  Result: 54.     // pub = 3,  pub2 = 2,   pub3 = 9,  pub4 = 1
    ///     //  Result: 324.    // pub = 3,  pub2 = 12,  pub3 = 9,  pub4 = 1
    ///     //  Result: 1404.   // pub = 13, pub2 = 12,  pub3 = 9,  pub4 = 1
    ///     //  Result: 2964.   // pub = 13, pub2 = 12,  pub3 = 19, pub4 = 1
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with the first publisher.
    ///   - publisher2: A third publisher to combine with the first publisher.
    ///   - publisher3: A fourth publisher to combine with the first publisher.
    ///   - transform: A closure that receives the most-recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this publisher and three other publishers.
    public func combineLatest<P, Q, R, T>(_ publisher1: P, _ publisher2: Q, _ publisher3: R, _ transform: @escaping (Self.Output, P.Output, Q.Output, R.Output) -> T) -> Publishers.Map<Publishers.CombineLatest4<Self, P, Q, R>, T> where P: Publisher, Q: Publisher, R: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        Publishers.CombineLatest4(self, publisher1, publisher2, publisher3).map(transform)
    }
}

// MARK: - CombineLatest Publishers

extension Publishers {
    /// A publisher that receives and combines the latest elements from two publishers.
    public struct CombineLatest<A, B>: Publisher where A: Publisher, B: Publisher, A.Failure == B.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces two-element tuples of the upstream publishers' output types.
        public typealias Output = (A.Output, B.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher produces the failure type shared by its upstream publishers.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        /// Creates a publisher that receives and combines the latest elements from two publishers.
        /// - Parameters:
        ///   - a: The first upstream publisher.
        ///   - b: The second upstream publisher.
        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b
        }

        public func receive<S>(subscriber: S) where S: Subscriber, B.Failure == S.Failure, S.Input == (A.Output, B.Output) {
            typealias Inner = CombineLatest2Inner<A.Output, B.Output, Failure, S>
            let inner = Inner(downstream: subscriber, upstreamCount: 2)
            a.subscribe(Inner.Side(index: 0, combiner: inner))
            b.subscribe(Inner.Side(index: 1, combiner: inner))
            inner.subscribe()
        }
    }

    /// A publisher that receives and combines the latest elements from three publishers.
    public struct CombineLatest3<A, B, C>: Publisher where A: Publisher, B: Publisher, C: Publisher, A.Failure == B.Failure, B.Failure == C.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces three-element tuples of the upstream publishers' output types.
        public typealias Output = (A.Output, B.Output, C.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher produces the failure type shared by its upstream publishers.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<S>(subscriber: S) where S: Subscriber, C.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output) {
            typealias Inner = CombineLatest3Inner<A.Output, B.Output, C.Output, Failure, S>
            let inner = Inner(downstream: subscriber, upstreamCount: 3)
            a.subscribe(Inner.Side(index: 0, combiner: inner))
            b.subscribe(Inner.Side(index: 1, combiner: inner))
            c.subscribe(Inner.Side(index: 2, combiner: inner))
            inner.subscribe()
        }
    }

    /// A publisher that receives and combines the latest elements from four publishers.
    public struct CombineLatest4<A, B, C, D>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces four-element tuples of the upstream publishers' output types.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher produces the failure type shared by its upstream publishers.
        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output, D.Output) {
            typealias Inner = CombineLatest4Inner<A.Output, B.Output, C.Output, D.Output, Failure, S>
            let inner = Inner(downstream: subscriber, upstreamCount: 4)
            a.subscribe(Inner.Side(index: 0, combiner: inner))
            b.subscribe(Inner.Side(index: 1, combiner: inner))
            c.subscribe(Inner.Side(index: 2, combiner: inner))
            d.subscribe(Inner.Side(index: 3, combiner: inner))
            inner.subscribe()
        }
    }
}

// MARK: - Equatable conformances

extension Publishers.CombineLatest: Equatable where A: Equatable, B: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A combineLatest publisher to compare for equality.
    ///   - rhs: Another combineLatest publisher to compare for equality.
    /// - Returns: `true` if the corresponding upstream publishers of each combineLatest publisher are equal; otherwise `false`.
    public static func == (lhs: Publishers.CombineLatest<A, B>, rhs: Publishers.CombineLatest<A, B>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Publishers.CombineLatest3: Equatable where A: Equatable, B: Equatable, C: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A combineLatest publisher to compare for equality.
    ///   - rhs: Another combineLatest publisher to compare for equality.
    /// - Returns: `true` if the corresponding upstream publishers of each combineLatest publisher are equal; otherwise `false`.
    public static func == (lhs: Publishers.CombineLatest3<A, B, C>, rhs: Publishers.CombineLatest3<A, B, C>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

extension Publishers.CombineLatest4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A combineLatest publisher to compare for equality.
    ///   - rhs: Another combineLatest publisher to compare for equality.
    /// - Returns: `true` if the corresponding upstream publishers of each combineLatest publisher are equal; otherwise `false`.
    public static func == (lhs: Publishers.CombineLatest4<A, B, C, D>, rhs: Publishers.CombineLatest4<A, B, C, D>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}

// MARK: - AbstractCombineLatest

private class AbstractCombineLatest<
    Output,
    Failure,
    Downstream
>
    where Downstream: Subscriber,
    Downstream.Input == Output,
    Downstream.Failure == Failure {
    let downstream: Downstream
    var buffers: [Any?]
    var subscriptions: [Subscription?]
    var demand = Subscribers.Demand.none
    var recursion = false
    var finished = false
    var cancelled = false
    let upstreamCount: Int
    var finishCount = 0
    let lock = UnfairLock.allocate()
    let downstreamLock = UnfairRecursiveLock.allocate()
    var established = false
    var pendingCompletion: Subscribers.Completion<Failure>?

    init(downstream: Downstream, upstreamCount: Int) {
        self.downstream = downstream
        self.buffers = Array(repeating: nil, count: upstreamCount)
        self.subscriptions = Array(repeating: nil, count: upstreamCount)
        self.upstreamCount = upstreamCount
    }

    deinit {
        lock.deallocate()
        downstreamLock.deallocate()
    }
    
    final func subscribe() {
        downstream.receive(subscription: self)
        lock.lock()
        established = true
        let completion = pendingCompletion
        pendingCompletion = nil
        lock.unlock()
        if let completion  {
            downstreamLock.lock()
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
    }

    func convert(values _: [Any?]) -> Output {
        abstractMethod()
    }

    final func receive(subscription: Subscription, index: Int) {
        precondition(upstreamCount > index)
        lock.lock()
        guard !cancelled,
              subscriptions[index] == nil else {
            lock.unlock()
            subscription.cancel()
            return
        }
        subscriptions[index] = subscription
        lock.unlock()
    }

    // FIXME: To be audited
    final func receive(_ input: Any, index: Int) -> Subscribers.Demand {
        precondition(upstreamCount > index)
        lock.lock()
        guard !cancelled,!finished else {
            lock.unlock()
            return .none
        }
        buffers[index] = input
        let buffers = buffers
        guard !recursion, demand != 0, buffers.allSatisfy({ $0 != nil }) else {
            lock.unlock()
            return .none
        }
        demand -= 1
        lock.unlock()
        let input = convert(values: buffers)
        lock.lock()
        recursion = true
        lock.unlock()
        downstreamLock.lock()
        let newDemand = downstream.receive(input)
        downstreamLock.unlock()
        lock.lock()
        recursion = false
        demand += newDemand
        lock.unlock()
        return newDemand
    }

    // FIXME: To be audited
    final func receive(completion: Subscribers.Completion<Failure>, index: Int) {
        switch completion {
        case .finished:
            lock.lock()
            guard !finished else {
                lock.unlock()
                return
            }
            finishCount += 1
            subscriptions[index] = nil
            if finishCount == upstreamCount {
                finished = true
                buffers = Array(repeating: nil, count: upstreamCount)
                if established {
                    lock.unlock()
                    downstreamLock.lock()
                    downstream.receive(completion: completion)
                    downstreamLock.unlock()
                } else {
                    pendingCompletion = completion
                    lock.unlock()
                }
            } else {
                lock.unlock()
            }
        case .failure:
            lock.lock()
            if finished {
                let subscriptions = subscriptions
                lock.unlock()
                for (i, subscription) in subscriptions.enumerated() where i != index {
                    subscription?.cancel()
                }
            } else {
                finished = true
                let subscriptions = subscriptions
                self.subscriptions = Array(repeating: nil, count: upstreamCount)
                buffers = Array(repeating: nil, count: upstreamCount)
                let established = established
                if !established {
                    pendingCompletion = completion
                }
                lock.unlock()
                for (i, subscription) in subscriptions.enumerated() where i != index {
                    subscription?.cancel()
                }
                if established {
                    downstreamLock.lock()
                    downstream.receive(completion: completion)
                    downstreamLock.unlock()
                }
            }
        }
    }
}

extension AbstractCombineLatest: Subscription {
    final func request(_ demand: Subscribers.Demand) {
        demand.assertNonZero()
        lock.lock()
        guard !cancelled, !finished else {
            lock.unlock()
            return
        }
        let subscriptions = subscriptions
        self.demand += demand
        lock.unlock()
        for subscription in subscriptions {
            subscription?.request(demand)
        }
    }

    final func cancel() {
        lock.lock()
        let subscriptions = self.subscriptions
        cancelled = true
        self.subscriptions = Array(repeating: nil, count: upstreamCount)
        buffers = Array(repeating: nil, count: upstreamCount)
        lock.unlock()
        for subscription in subscriptions {
            subscription?.cancel()
        }
    }
}

extension AbstractCombineLatest: CustomStringConvertible {
    final var description: String { "CombineLatest" }
}

extension AbstractCombineLatest: CustomPlaygroundDisplayConvertible {
    final var playgroundDescription: Any { description }
}

extension AbstractCombineLatest: CustomReflectable {
    var customMirror: Mirror {
        lock.lock()
        defer { lock.unlock() }
        return Mirror(self, children: [
            "downstream": downstream,
            "upstreamSubscriptions": subscriptions,
            "demand": demand,
            "buffers": buffers,
        ])
    }
}

// MARK: - AbstractCombineLatest.Side

extension AbstractCombineLatest {
    struct Side<Input> {
        let index: Int
        let combiner: AbstractCombineLatest
        // `CombineIdentifier(AbstractCombineLatest.self)` will cause build fail on non-ObjC platform
        // Even we can make trick to compile successfully by using `CombineIdentifier(AbstractCombineLatest.self as AnyObject)`
        // The runtime behavior is still not correct and may give different result here.
        // Tracked by https://github.com/apple/swift/issues/70645
        #if !canImport(ObjectiveC)
        let combineIdentifier = CombineIdentifier()
        #endif
        
        init(index: Int, combiner: AbstractCombineLatest) {
            self.index = index
            self.combiner = combiner
        }
    }
}

extension AbstractCombineLatest.Side: Subscriber {
    // `CombineIdentifier(AbstractCombineLatest.self)` will cause build fail on non-ObjC platform
    // Even we can make trick to compile successfully by using `CombineIdentifier(AbstractCombineLatest.self as AnyObject)`
    // The runtime behavior is still not correct and may give different result here.
    // Tracked by https://github.com/apple/swift/issues/70645
    #if canImport(ObjectiveC)
    // NOTE: Audited with Combine 2023 release.
    // A better implementation is `let combineIdentifier = CombineIdentifier()` IMO.
    var combineIdentifier: CombineIdentifier {
        CombineIdentifier(AbstractCombineLatest.self)
    }
    #endif
    
    func receive(subscription: Subscription) {
        combiner.receive(subscription: subscription, index: index)
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        combiner.receive(input, index: index)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        combiner.receive(completion: completion, index: index)
    }
}

extension AbstractCombineLatest.Side: CustomStringConvertible {
    var description: String { "CombineLatest" }
}

// MARK: - CombineLatest Inners

private final class CombineLatest2Inner<
    Output0,
    Output1,
    Failure,
    Downstream
>: AbstractCombineLatest<
    (Output0, Output1),
    Failure,
    Downstream
> where Downstream: Subscriber,
    Downstream.Input == (Output0, Output1),
    Downstream.Failure == Failure {
    override func convert(values: [Any?]) -> (Output0, Output1) {
        (
            values[0] as! Output0,
            values[1] as! Output1
        )
    }
}

private final class CombineLatest3Inner<
    Output0,
    Output1,
    Output2,
    Failure,
    Downstream
>: AbstractCombineLatest<
    (Output0, Output1, Output2),
    Failure,
    Downstream
> where Downstream: Subscriber,
    Downstream.Input == (Output0, Output1, Output2),
    Downstream.Failure == Failure {
    override func convert(values: [Any?]) -> (Output0, Output1, Output2) {
        (
            values[0] as! Output0,
            values[1] as! Output1,
            values[2] as! Output2
        )
    }
}

private final class CombineLatest4Inner<
    Output0,
    Output1,
    Output2,
    Output3,
    Failure,
    Downstream: Subscriber
>: AbstractCombineLatest<
    (Output0, Output1, Output2, Output3),
    Failure,
    Downstream
> where Downstream: Subscriber,
    Downstream.Input == (Output0, Output1, Output2, Output3),
    Downstream.Failure == Failure {
    override func convert(values: [Any?]) -> (Output0, Output1, Output2, Output3) {
        (
            values[0] as! Output0,
            values[1] as! Output1,
            values[2] as! Output2,
            values[3] as! Output3
        )
    }
}
