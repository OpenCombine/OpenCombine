//
//  Publishers.Zip.swift
//  OpenCombine
//
//  Created by Kyle on 2023/7/25.
//  Audited for Combine 2023

#if canImport(COpenCombineHelpers)
@_implementationOnly import COpenCombineHelpers
#endif

extension Publisher {
    /// Combines elements from another publisher and deliver pairs of elements as tuples.
    ///
    /// Use ``Publisher/zip(_:)`` to combine the latest elements from two publishers and emit a tuple to the downstream. The returned publisher waits until both publishers have emitted an event, then delivers the oldest unconsumed event from each publisher together as a tuple to the subscriber.
    ///
    /// Much like a zipper or zip fastener on a piece of clothing pulls together rows of teeth to link the two sides, ``Publisher/zip(_:)`` combines streams from two different publishers by linking pairs of elements from each side.
    ///
    /// In this example, `numbers` and `letters` are ``PassthroughSubject``s that emit values; once ``Publisher/zip(_:)`` receives one value from each, it publishes the pair as a tuple to the downstream subscriber. It then waits for the next pair of values.
    ///
    ///      let numbersPub = PassthroughSubject<Int, Never>()
    ///      let lettersPub = PassthroughSubject<String, Never>()
    ///
    ///      cancellable = numbersPub
    ///          .zip(lettersPub)
    ///          .sink { print("\($0)") }
    ///      numbersPub.send(1)    // numbersPub: 1      lettersPub:        zip output: <none>
    ///      numbersPub.send(2)    // numbersPub: 1,2    lettersPub:        zip output: <none>
    ///      lettersPub.send("A")  // numbers: 1,2       letters:"A"        zip output: <none>
    ///      numbersPub.send(3)    // numbers: 1,2,3     letters:           zip output: (1,"A")
    ///      lettersPub.send("B")  // numbers: 1,2,3     letters: "B"       zip output: (2,"B")
    ///
    ///      // Prints:
    ///      //  (1, "A")
    ///      //  (2, "B")
    ///
    /// If either upstream publisher finishes successfully or fails with an error, the zipped publisher does the same.
    ///
    /// - Parameter other: Another publisher.
    /// - Returns: A publisher that emits pairs of elements from the upstream publishers as tuples.
    public func zip<P>(_ other: P) -> Publishers.Zip<Self, P> where P: Publisher, Self.Failure == P.Failure {
        Publishers.Zip(self, other)
    }

    /// Combines elements from another publisher and delivers a transformed output.
    ///
    /// Use ``Publisher/zip(_:_:)-7ve7u`` to return a new publisher that combines the elements from two publishers using a transformation you specify to publish a new value to the downstream.  The returned publisher waits until both publishers have emitted an event, then delivers the oldest unconsumed event from each publisher together that the operator uses in the transformation.
    ///
    /// In this example, ``PassthroughSubject`` instances `numbersPub` and `lettersPub` emit values; ``Publisher/zip(_:_:)-7ve7u`` receives the oldest value from each publisher, uses the `Int` from `numbersPub` and publishes a string that repeats the [String](https://developer.apple.com/documentation/swift/string) from `lettersPub` that many times.
    ///
    ///     let numbersPub = PassthroughSubject<Int, Never>()
    ///     let lettersPub = PassthroughSubject<String, Never>()
    ///     cancellable = numbersPub
    ///         .zip(lettersPub) { anInt, aLetter in
    ///             String(repeating: aLetter, count: anInt)
    ///         }
    ///         .sink { print("\($0)") }
    ///     numbersPub.send(1)     // numbersPub: 1      lettersPub:       zip output: <none>
    ///     numbersPub.send(2)     // numbersPub: 1,2    lettersPub:       zip output: <none>
    ///     numbersPub.send(3)     // numbersPub: 1,2,3  lettersPub:       zip output: <none>
    ///     lettersPub.send("A")   // numbersPub: 1,2,3  lettersPub: "A"   zip output: "A"
    ///     lettersPub.send("B")   // numbersPub: 2,3    lettersPub: "B"   zip output: "BB"
    ///     // Prints:
    ///     //  A
    ///     //  BB
    ///
    /// If either upstream publisher finishes successfully or fails with an error, the zipped publisher does the same.
    ///
    /// - Parameters:
    ///   - other: Another publisher.
    ///   - transform: A closure that receives the most-recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that uses the `transform` closure to emit new elements, produced by combining the most recent value from two upstream publishers.
    public func zip<P, T>(_ other: P, _ transform: @escaping (Self.Output, P.Output) -> T) -> Publishers.Map<Publishers.Zip<Self, P>, T> where P: Publisher, Self.Failure == P.Failure {
        zip(other).map(transform)
    }

    /// Combines elements from two other publishers and delivers groups of elements as tuples.
    ///
    /// Use ``Publisher/zip(_:_:)-2p498`` to return a new publisher that combines the elements from two additional publishers to publish a tuple to the downstream. The returned publisher waits until all three publishers have emitted an event, then delivers the oldest unconsumed event from each publisher as a tuple to the subscriber.
    ///
    /// In this example, `numbersPub`, `lettersPub` and `emojiPub` are each a ``PassthroughSubject``;
    /// ``Publisher/zip(_:_:)-2p498`` receives the oldest unconsumed value from each publisher and combines them into a tuple that it republishes to the downstream:
    ///
    ///     let numbersPub = PassthroughSubject<Int, Never>()
    ///     let lettersPub = PassthroughSubject<String, Never>()
    ///     let emojiPub = PassthroughSubject<String, Never>()
    ///
    ///     cancellable = numbersPub
    ///         .zip(lettersPub, emojiPub)
    ///         .sink { print("\($0)") }
    ///     numbersPub.send(1)     // numbersPub: 1      lettersPub:          emojiPub:        zip output: <none>
    ///     numbersPub.send(2)     // numbersPub: 1,2    lettersPub:          emojiPub:        zip output: <none>
    ///     numbersPub.send(3)     // numbersPub: 1,2,3  lettersPub:          emojiPub:        zip output: <none>
    ///     lettersPub.send("A")   // numbersPub: 1,2,3  lettersPub: "A"      emojiPub:        zip output: <none>
    ///     emojiPub.send("😀")    // numbersPub: 2,3    lettersPub: "A"      emojiPub: "😀"   zip output: (1, "A", "😀")
    ///     lettersPub.send("B")   // numbersPub: 2,3    lettersPub: "B"      emojiPub:        zip output: <none>
    ///     emojiPub.send("🥰")    // numbersPub: 3      lettersPub:          emojiPub:        zip output: (2, "B", "🥰")
    ///
    ///     // Prints:
    ///     //  (1, "A", "😀")
    ///     //  (2, "B", "🥰")
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers as tuples.
    public func zip<P, Q>(_ publisher1: P, _ publisher2: Q) -> Publishers.Zip3<Self, P, Q> where P: Publisher, Q: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure {
        Publishers.Zip3(self, publisher1, publisher2)
    }

    /// Combines elements from two other publishers and delivers a transformed output.
    ///
    /// Use ``Publisher/zip(_:_:_:)-19jxo`` to return a new publisher that combines the elements from two other publishers using a transformation you specify to publish a new value to the downstream subscriber. The returned publisher waits until all three publishers have emitted an event, then delivers the oldest unconsumed event from each publisher together that the operator uses in the transformation.
    ///
    /// In this example, `numbersPub`, `lettersPub` and `emojiPub` are each a ``PassthroughSubject`` that emit values; ``Publisher/zip(_:_:_:)-19jxo`` receives the oldest value from each publisher and uses the `Int` from `numbersPub` and publishes a string that repeats the [String](https://developer.apple.com/documentation/swift/string) from `lettersPub` and `emojiPub` that many times.
    ///
    ///     let numbersPub = PassthroughSubject<Int, Never>()
    ///     let lettersPub = PassthroughSubject<String, Never>()
    ///     let emojiPub = PassthroughSubject<String, Never>()
    ///
    ///     cancellable = numbersPub
    ///         .zip(letters, emoji) { anInt, aLetter, anEmoji in
    ///             ("\(String(repeating: anEmoji, count: anInt)) \(String(repeating: aLetter, count: anInt))")
    ///         }
    ///         .sink { print("\($0)") }
    ///
    ///     numbersPub.send(1)     // numbersPub: 1      lettersPub:        emojiPub:            zip output: <none>
    ///     numbersPub.send(2)     // numbersPub: 1,2    lettersPub:        emojiPub:            zip output: <none>
    ///     numbersPub.send(3)     // numbersPub: 1,2,3  lettersPub:        emojiPub:            zip output: <none>
    ///     lettersPub.send("A")   // numbersPub: 1,2,3  lettersPub: "A"    emojiPub:            zip output: <none>
    ///     emojiPub.send("😀")    // numbersPub: 2,3    lettersPub: "A"    emojiPub:"😀"        zip output: "😀 A"
    ///     lettersPub.send("B")   // numbersPub: 2,3    lettersPub: "B"    emojiPub:            zip output: <none>
    ///     emojiPub.send("🥰")    // numbersPub: 3      lettersPub:        emojiPub:"😀", "🥰"  zip output: "🥰🥰 BB"
    ///
    ///     // Prints:
    ///     // 😀 A
    ///     // 🥰🥰 BB
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - transform: A closure that receives the most-recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that uses the `transform` closure to emit new elements, produced by combining the most recent value from three upstream publishers.
    public func zip<P, Q, T>(_ publisher1: P, _ publisher2: Q, _ transform: @escaping (Self.Output, P.Output, Q.Output) -> T) -> Publishers.Map<Publishers.Zip3<Self, P, Q>, T> where P: Publisher, Q: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure {
        zip(publisher1, publisher2).map(transform)
    }

    /// Combines elements from three other publishers and delivers groups of elements as tuples.
    ///
    /// Use ``Publisher/zip(_:_:_:)-67czn`` to return a new publisher that combines the elements from three other publishers to publish a tuple to the downstream subscriber. The returned publisher waits until all four publishers have emitted an event, then delivers the oldest unconsumed event from each publisher as a tuple to the subscriber.
    ///
    /// In this example, several ``PassthroughSubject`` instances emit values; ``Publisher/zip(_:_:_:)-67czn`` receives the oldest unconsumed value from each publisher and combines them into a tuple that it republishes to the downstream:
    ///
    ///     let numbersPub = PassthroughSubject<Int, Never>()
    ///     let lettersPub = PassthroughSubject<String, Never>()
    ///     let emojiPub = PassthroughSubject<String, Never>()
    ///     let fractionsPub  = PassthroughSubject<Double, Never>()
    ///
    ///     cancellable = numbersPub
    ///         .zip(lettersPub, emojiPub, fractionsPub)
    ///         .sink { print("\($0)") }
    ///     numbersPub.send(1)         // numbersPub: 1       lettersPub:        emojiPub:       fractionsPub:         zip output: <none>
    ///     numbersPub.send(2)         // numbersPub: 1,2     lettersPub:        emojiPub:       fractionsPub:         zip output: <none>
    ///     numbersPub.send(3)         // numbersPub: 1,2,3   lettersPub:        emojiPub:       fractionsPub:         zip output: <none>
    ///     fractionsPub.send(0.1)     // numbersPub: 1,2,3   lettersPub: "A"    emojiPub:       fractionsPub: 0.1     zip output: <none>
    ///     lettersPub.send("A")       // numbersPub: 1,2,3   lettersPub: "A"    emojiPub:       fractionsPub: 0.1     zip output: <none>
    ///     emojiPub.send("😀")        // numbersPub: 2,3     lettersPub: "A"    emojiPub: "😀"  fractionsPub: 0.1     zip output: (1, "A", "😀", 0.1)
    ///     lettersPub.send("B")       // numbersPub: 2,3     lettersPub: "B"    emojiPub:       fractionsPub:         zip output: <none>
    ///     fractionsPub.send(0.8)     // numbersPub: 2,3     lettersPub: "B"    emojiPub:       fractionsPub: 0.8     zip output: <none>
    ///     emojiPub.send("🥰")        // numbersPub: 3       lettersPub: "B"    emojiPub:       fractionsPub: 0.8     zip output: (2, "B", "🥰", 0.8)
    ///     // Prints:
    ///     //  (1, "A", "😀", 0.1)
    ///     //  (2, "B", "🥰", 0.8)
    ///
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - publisher3: A fourth publisher.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers as tuples.
    public func zip<P, Q, R>(_ publisher1: P, _ publisher2: Q, _ publisher3: R) -> Publishers.Zip4<Self, P, Q, R> where P: Publisher, Q: Publisher, R: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        Publishers.Zip4(self, publisher1, publisher2, publisher3)
    }

    /// Combines elements from three other publishers and delivers a transformed output.
    ///
    /// Use ``Publisher/zip(_:_:_:_:)`` to return a new publisher that combines the elements from three other publishers using a transformation you specify to publish a new value to the downstream subscriber. The returned publisher waits until all four publishers have emitted an event, then delivers the oldest unconsumed event from each publisher together that the operator uses in the transformation.
    ///
    /// In this example, the ``PassthroughSubject`` publishers, `numbersPub`,
    /// `fractionsPub`, `lettersPub`, and `emojiPub` emit values. The ``Publisher/zip(_:_:_:_:)`` operator receives the oldest value from each publisher and uses the `Int` from `numbersPub` and publishes a string that repeats the [String](https://developer.apple.com/documentation/swift/string) from `lettersPub` and `emojiPub` that many times and prints out the value in `fractionsPub`.
    ///
    ///     let numbersPub = PassthroughSubject<Int, Never>()      // first publisher
    ///     let lettersPub = PassthroughSubject<String, Never>()   // second
    ///     let emojiPub = PassthroughSubject<String, Never>()     // third
    ///     let fractionsPub  = PassthroughSubject<Double, Never>()// fourth
    ///
    ///     cancellable = numbersPub
    ///         .zip(lettersPub, emojiPub, fractionsPub) { anInt, aLetter, anEmoji, aFraction  in
    ///             ("\(String(repeating: anEmoji, count: anInt)) \(String(repeating: aLetter, count: anInt)) \(aFraction)")
    ///         }
    ///         .sink { print("\($0)") }
    ///
    ///     numbersPub.send(1)         // numbersPub: 1       lettersPub:          emojiPub:          zip output: <none>
    ///     numbersPub.send(2)         // numbersPub: 1,2     lettersPub:          emojiPub:          zip output: <none>
    ///     numbersPub.send(3)         // numbersPub: 1,2,3   lettersPub:          emojiPub:          zip output: <none>
    ///     fractionsPub.send(0.1)     // numbersPub: 1,2,3   lettersPub: "A"      emojiPub:          zip output: <none>
    ///     lettersPub.send("A")       // numbersPub: 1,2,3   lettersPub: "A"      emojiPub:          zip output: <none>
    ///     emojiPub.send("😀")        // numbersPub: 1,2,3   lettersPub: "A"      emojiPub:"😀"      zip output: "😀 A"
    ///     lettersPub.send("B")       // numbersPub: 2,3     lettersPub: "B"      emojiPub:          zip output: <none>
    ///     fractionsPub.send(0.8)     // numbersPub: 2,3     lettersPub: "A"      emojiPub:          zip output: <none>
    ///     emojiPub.send("🥰")        // numbersPub: 3       lettersPub: "B"      emojiPub:          zip output: "🥰🥰 BB"
    ///     // Prints:
    ///     //1 😀 A 0.1
    ///     //2 🥰🥰 BB 0.8
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - publisher3: A fourth publisher.
    ///   - transform: A closure that receives the most-recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that uses the `transform` closure to emit new elements, produced by combining the most recent value from four upstream publishers.
    public func zip<P, Q, R, T>(_ publisher1: P, _ publisher2: Q, _ publisher3: R, _ transform: @escaping (Self.Output, P.Output, Q.Output, R.Output) -> T) -> Publishers.Map<Publishers.Zip4<Self, P, Q, R>, T> where P: Publisher, Q: Publisher, R: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        zip(publisher1, publisher2, publisher3).map(transform)
    }
}

extension Publishers {
    /// A publisher created by applying the zip function to two upstream publishers.
    ///
    /// Use `Publishers.Zip` to combine the latest elements from two publishers and emit a tuple to the downstream. The returned publisher waits until both publishers have emitted an event, then delivers the oldest unconsumed event from each publisher together as a tuple to the subscriber.
    ///
    /// Much like a zipper or zip fastener on a piece of clothing pulls together rows of teeth to link the two sides, `Publishers.Zip` combines streams from two different publishers by linking pairs of elements from each side.
    ///
    /// If either upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    public struct Zip<A, B>: Publisher where A: Publisher, B: Publisher, A.Failure == B.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces two-element tuples, whose members' types correspond to the types produced by the upstream publishers.
        public typealias Output = (A.Output, B.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to zip.
        public let a: A

        /// Another publisher to zip.
        public let b: B

        /// Creates a publisher that applies the zip function to two upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to zip.
        ///   - b: Another publisher to zip.
        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b
        }

        public func receive<S>(subscriber: S) where S: Subscriber, B.Failure == S.Failure, S.Input == (A.Output, B.Output) {
            typealias Inner = Zip2Inner<A.Output, B.Output, Failure, S>
            let zip = Inner(downstream: subscriber, upstreamCount: 2)
            a.subscribe(Inner.Side(index: 0, zip: zip))
            b.subscribe(Inner.Side(index: 1, zip: zip))
        }
    }

    /// A publisher created by applying the zip function to three upstream publishers.
    ///
    /// Use a `Publishers.Zip3` to combine the latest elements from three publishers and emit a tuple to the downstream. The returned publisher waits until all three publishers have emitted an event, then delivers the oldest unconsumed event from each publisher as a tuple to the subscriber.
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    public struct Zip3<A, B, C>: Publisher where A: Publisher, B: Publisher, C: Publisher, A.Failure == B.Failure, B.Failure == C.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces three-element tuples, whose members' types correspond to the types produced by the upstream publishers.
        public typealias Output = (A.Output, B.Output, C.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to zip.
        public let a: A

        /// A second publisher to zip.
        public let b: B

        /// A third publisher to zip.
        public let c: C

        /// Creates a publisher that applies the zip function to three upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to zip.
        ///   - b: A second publisher to zip.
        ///   - c: A third publisher to zip.
        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<S>(subscriber: S) where S: Subscriber, C.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output) {
            typealias Inner = Zip3Inner<A.Output, B.Output, C.Output, Failure, S>
            let zip = Inner(downstream: subscriber, upstreamCount: 3)
            a.subscribe(Inner.Side(index: 0, zip: zip))
            b.subscribe(Inner.Side(index: 1, zip: zip))
            c.subscribe(Inner.Side(index: 2, zip: zip))
        }
    }

    /// A publisher created by applying the zip function to four upstream publishers.
    ///
    /// Use a `Publishers.Zip4` to combine the latest elements from four publishers and emit a tuple to the downstream. The returned publisher waits until all four publishers have emitted an event, then delivers the oldest unconsumed event from each publisher as a tuple to the subscriber.
    ///
    /// If any upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
    public struct Zip4<A, B, C, D>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {
        /// The kind of values published by this publisher.
        ///
        /// This publisher produces four-element tuples, whose members' types correspond to the types produced by the upstream publishers.
        public typealias Output = (A.Output, B.Output, C.Output, D.Output)

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to zip.
        public let a: A

        /// A second publisher to zip.
        public let b: B

        /// A third publisher to zip.
        public let c: C

        /// A fourth publisher to zip.
        public let d: D

        /// Creates a publisher created by applying the zip function to four upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to zip.
        ///   - b: A second publisher to zip.
        ///   - c: A third publisher to zip.
        ///   - d: A fourth publisher to zip.
        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output, D.Output) {
            typealias Inner = Zip4Inner<A.Output, B.Output, C.Output, D.Output, Failure, S>
            let zip = Inner(downstream: subscriber, upstreamCount: 4)
            a.subscribe(Inner.Side(index: 0, zip: zip))
            b.subscribe(Inner.Side(index: 1, zip: zip))
            c.subscribe(Inner.Side(index: 2, zip: zip))
            d.subscribe(Inner.Side(index: 3, zip: zip))
        }
    }
}

extension Publishers.Zip: Equatable where A: Equatable, B: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A zip publisher to compare for equality.
    ///   - rhs: Another zip publisher to compare for equality.
    /// - Returns: `true` if the corresponding upstream publishers of each zip publisher are equal; otherwise `false`.
    public static func == (lhs: Publishers.Zip<A, B>, rhs: Publishers.Zip<A, B>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Publishers.Zip3: Equatable where A: Equatable, B: Equatable, C: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A zip publisher to compare for equality.
    ///   - rhs: Another zip publisher to compare for equality.
    /// - Returns: `true` if the corresponding upstream publishers of each zip publisher are equal; otherwise `false`.
    public static func == (lhs: Publishers.Zip3<A, B, C>, rhs: Publishers.Zip3<A, B, C>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

extension Publishers.Zip4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A zip publisher to compare for equality.
    ///   - rhs: Another zip publisher to compare for equality.
    /// - Returns: `true` if the corresponding upstream publishers of each zip publisher are equal; otherwise `false`.
    public static func == (lhs: Publishers.Zip4<A, B, C, D>, rhs: Publishers.Zip4<A, B, C, D>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}

// MARK: - AbstractZip

private class AbstractZip<Input, Failure, Downstream> where Downstream: Subscriber, Input == Downstream.Input, Failure == Downstream.Failure {
    let downstream: Downstream
    var buffers: [[Any]]
    var subscriptions: [Subscription?]
    var cancelled: Bool
    var errored: Bool
    var finished: Bool
    var upstreamFinished: [Bool]
    let upstreamCount: Int
    var lock: UnfairLock
    let downstreamLock: UnfairRecursiveLock
    var recursive: Bool
    var pendingDemand: Subscribers.Demand
    var pendingCompletion: Subscribers.Completion<Failure>?

    init(downstream: Downstream, upstreamCount: Int) {
        self.downstream = downstream
        self.buffers = Array(repeating: [], count: upstreamCount)
        self.subscriptions = Array(repeating: nil, count: upstreamCount)
        self.cancelled = false
        self.errored = false
        self.finished = false
        self.upstreamFinished = Array(repeating: false, count: upstreamCount)
        self.upstreamCount = upstreamCount
        self.lock = UnfairLock.allocate()
        self.downstreamLock = UnfairRecursiveLock.allocate()
        self.recursive = false
        self.pendingDemand = .none
        self.pendingCompletion = nil
    }

    deinit {
        lock.deallocate()
        downstreamLock.deallocate()
    }

    func convert(values _: [Any]) -> Input {
        fatalError("Abstract method")
    }

    func receive(subscription: Subscription, index: Int) {
        precondition(upstreamCount > index)
        lock.lock()
        guard !cancelled, subscriptions[index] == nil else {
            lock.unlock()
            subscription.cancel()
            return
        }
        subscriptions[index] = subscription
        let containsNil = subscriptions.contains { $0 == nil }
        recursive = !containsNil
        lock.unlock()
        if !containsNil {
            downstreamLock.lock()
            downstream.receive(subscription: self)
            downstreamLock.unlock()
            lock.lock()
            recursive = false
            if let pendingCompletion {
                subscription.cancel()
                lockedSendCompletion(completion: pendingCompletion)
            } else {
                resolvePendingDemandAndUnlock()
            }
        }
    }

    func receive(_ value: Any, index: Int) -> Subscribers.Demand {
        precondition(upstreamCount > index)
        lock.lock()
        guard !cancelled, !errored, !finished else {
            lock.unlock()
            return .none
        }
        buffers[index].append(value)
        if buffers.contains(where: { $0.isEmpty }) {
            lock.unlock()
            return .none
        }
        var newBuffers: [[Any]] = []
        var values: [Any] = []
        var newFinished = false
        for i in buffers.indices {
            var buffer = buffers[i]
            values.append(buffer.remove(at: 0))
            newBuffers.append(buffer)
            if upstreamFinished[i] {
                newFinished = newFinished || buffer.isEmpty
            }
        }
        buffers = newBuffers
        recursive = true
        lock.unlock()
        let input = convert(values: values)
        downstreamLock.lock()
        let demand = downstream.receive(input)
        downstreamLock.unlock()
        lock.lock()
        recursive = false
        if newFinished {
            finished = true
            lockedSendCompletion(completion: .finished)
            return .none
        } else {
            let newDemand = demand + pendingDemand
            pendingDemand = .none
            if newDemand == .none {
                lock.unlock()
                return .none
            }
            let subscriptions = self.subscriptions
            lock.unlock()
            for (i, subscription) in subscriptions.enumerated() {
                if let subscription, i != index {
                    subscription.request(newDemand)
                }
            }
            return newDemand
        }
    }

    func receive(completion: Subscribers.Completion<Failure>, index: Int) {
        lock.lock()
        guard !cancelled, !errored, !finished else {
            lock.unlock()
            return
        }
        switch completion {
        case .finished:
            upstreamFinished[index] = true
            if buffers[index].isEmpty {
                finished = true
                lockedSendCompletion(completion: completion)
            } else {
                lock.unlock()
            }
        case .failure(_):
            errored = true
            lockedSendCompletion(completion: completion)
        }
    }

    private func lockedSendCompletion(completion: Subscribers.Completion<Failure>) {
        buffers = Array(repeating: [], count: upstreamCount)
        let subscriptions = self.subscriptions
        recursive = true
        pendingCompletion = completion
        lock.unlock()
        for (index, subscription) in subscriptions.enumerated() where !upstreamFinished[index] {
            guard let subscription else {
                return
            }
            subscription.cancel()
        }
        downstreamLock.lock()
        downstream.receive(completion: completion)
        downstreamLock.unlock()
        lock.lock()
        self.subscriptions = Array(repeating: nil, count: upstreamCount)
        pendingCompletion = nil
        recursive = false
        pendingDemand = .none
        lock.unlock()
    }

    private func resolvePendingDemandAndUnlock() {
        let subscriptions = self.subscriptions
        let demand = pendingDemand
        pendingDemand = .none
        lock.unlock()
        guard demand != .none, !subscriptions.isEmpty else {
            return
        }
        for subscription in subscriptions {
            subscription?.request(demand)
        }
    }
}

extension AbstractZip: Subscription {
    func request(_ demand: Subscribers.Demand) {
        demand.assertNonZero()
        lock.lock()
        guard !recursive else {
            pendingDemand += demand
            lock.unlock()
            return
        }
        guard !cancelled, !errored, !finished else {
            lock.unlock()
            return
        }
        let subscriptions = self.subscriptions
        lock.unlock()
        for subscription in subscriptions {
            subscription?.request(demand)
        }
    }

    func cancel() {
        lock.lock()
        guard !cancelled else {
            lock.unlock()
            return
        }
        let subscriptions = self.subscriptions
        cancelled = true
        self.subscriptions = Array(repeating: nil, count: upstreamCount)
        self.buffers = Array(repeating: [], count: upstreamCount)
        lock.unlock()
        for subscription in subscriptions {
            subscription?.cancel()
        }
    }
}

extension AbstractZip {
    struct Side<SideInput> {
        let index: Int
        let zip: AbstractZip
        let combineIdentifier: CombineIdentifier

        init(index: Int, zip: AbstractZip) {
            self.index = index
            self.zip = zip
            self.combineIdentifier = CombineIdentifier()
        }
    }
}

extension AbstractZip.Side: Subscriber {
    typealias Input = SideInput

    func receive(subscription: Subscription) {
        zip.receive(subscription: subscription, index: index)
    }

    func receive(_ input: SideInput) -> Subscribers.Demand {
        zip.receive(input, index: index)
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        zip.receive(completion: completion, index: index)
    }
}

extension AbstractZip: CustomStringConvertible {
    var description: String { "Zip" }
}

extension AbstractZip.Side: CustomStringConvertible {
    var description: String { "Zip" }
}

extension AbstractZip: CustomPlaygroundDisplayConvertible {
    var playgroundDescription: Any { description }
}

extension AbstractZip.Side: CustomPlaygroundDisplayConvertible {
    var playgroundDescription: Any { description }
}

extension AbstractZip: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension AbstractZip.Side: CustomReflectable {
    var customMirror: Mirror {
        Mirror(self, children: ["parentSubscription" : zip.combineIdentifier])
    }
}

// MARK: ZipInner

private final class Zip2Inner<Input1, Input2, Failure, Downstream>: AbstractZip<(Input1, Input2), Failure, Downstream> where Downstream: Subscriber, (Input1, Input2) == Downstream.Input, Failure == Downstream.Failure {
    override func convert(values: [Any]) -> (Input1, Input2) {
        (values[0] as! Input1, values[1] as! Input2)
    }
}

private final class Zip3Inner<Input1, Input2, Input3, Failure, Downstream>: AbstractZip<(Input1, Input2, Input3), Failure, Downstream> where Downstream: Subscriber, (Input1, Input2, Input3) == Downstream.Input, Failure == Downstream.Failure {
    override func convert(values: [Any]) -> (Input1, Input2, Input3) {
        (values[0] as! Input1, values[1] as! Input2, values[2] as! Input3)
    }
}

private final class Zip4Inner<Input1, Input2, Input3, Input4, Failure, Downstream>: AbstractZip<(Input1, Input2, Input3, Input4), Failure, Downstream> where Downstream: Subscriber, (Input1, Input2, Input3, Input4) == Downstream.Input, Failure == Downstream.Failure {
    override func convert(values: [Any]) -> (Input1, Input2, Input3, Input4) {
        (values[0] as! Input1, values[1] as! Input2, values[2] as! Input3, values[3] as! Input4)
    }
}
