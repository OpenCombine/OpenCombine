//
//  Publishers.Merge.swift
//  OpenCombine
//
//  Created by Kyle on 2023/11/21.
//  Audited for 2023 Release

#if canImport(COpenCombineHelpers)
@_implementationOnly import COpenCombineHelpers
#endif

// MARK: - merge methods on Publisher

extension Publisher {
    /// Combines elements from this publisher with those from another publisher, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:)-394v9`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:)``. To combine elements from multiple upstream publishers, use ``Publisher/zip(_:)``.
    ///
    /// In this example, as ``Publisher/merge(with:)-394v9`` receives input from either upstream publisher, it republishes it to the downstream:
    ///
    ///     let publisher = PassthroughSubject<Int, Never>()
    ///     let pub2 = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = publisher
    ///         .merge(with: pub2)
    ///         .sink { print("\($0)", terminator: " " )}
    ///
    ///     publisher.send(2)
    ///     pub2.send(2)
    ///     publisher.send(3)
    ///     pub2.send(22)
    ///     publisher.send(45)
    ///     pub2.send(22)
    ///     publisher.send(17)
    ///
    ///     // Prints: "2 2 3 22 45 22 17"
    ///
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameter other: Another publisher.
    /// - Returns: A publisher that emits an event when either upstream publisher emits an event.
    public func merge<P>(with other: P) -> Publishers.Merge<Self, P> where P: Publisher, Self.Failure == P.Failure, Self.Output == P.Output {
        Publishers.Merge(self, other)
    }
    
    /// Combines elements from this publisher with those from two other publishers, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:_:)`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:_:)-81vgd``.
    /// To combine elements from multiple upstream publishers, use ``Publisher/zip(_:_:)-2p498``.
    ///
    /// In this example, as ``Publisher/merge(with:_:)`` receives input from the upstream publishers, it republishes the interleaved elements to the downstream:
    ///
    ///     let pubA = PassthroughSubject<Int, Never>()
    ///     let pubB = PassthroughSubject<Int, Never>()
    ///     let pubC = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pubA
    ///         .merge(with: pubB, pubC)
    ///         .sink { print("\($0)", terminator: " " )}
    ///
    ///     pubA.send(1)
    ///     pubB.send(40)
    ///     pubC.send(90)
    ///     pubA.send(2)
    ///     pubB.send(50)
    ///     pubC.send(100)
    ///
    ///     // Prints: "1 40 90 2 50 100"
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C>(with b: B, _ c: C) -> Publishers.Merge3<Self, B, C> where B: Publisher, C: Publisher, Self.Failure == B.Failure, Self.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output {
        Publishers.Merge3(self, b, c)
    }

    /// Combines elements from this publisher with those from three other publishers, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:_:_:)`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:_:_:)-7mt86``.
    /// To combine elements from multiple upstream publishers, use ``Publisher/zip(_:_:_:)-67czn``.
    ///
    /// In this example, as ``Publisher/merge(with:_:_:)`` receives input from the upstream publishers, it republishes the interleaved elements to the downstream:
    ///
    ///     let pubA = PassthroughSubject<Int, Never>()
    ///     let pubB = PassthroughSubject<Int, Never>()
    ///     let pubC = PassthroughSubject<Int, Never>()
    ///     let pubD = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pubA
    ///         .merge(with: pubB, pubC, pubD)
    ///         .sink { print("\($0)", terminator: " " )}
    ///
    ///     pubA.send(1)
    ///     pubB.send(40)
    ///     pubC.send(90)
    ///     pubD.send(-1)
    ///     pubA.send(2)
    ///     pubB.send(50)
    ///     pubC.send(100)
    ///     pubD.send(-2)
    ///
    ///     // Prints: "1 40 90 -1 2 50 100 -2 "
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D>(with b: B, _ c: C, _ d: D) -> Publishers.Merge4<Self, B, C, D> where B: Publisher, C: Publisher, D: Publisher, Self.Failure == B.Failure, Self.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output {
        Publishers.Merge4(self, b, c, d)
    }

    /// Combines elements from this publisher with those from four other publishers, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:_:_:_:)`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:_:_:)-7mt86``.
    /// To combine elements from multiple upstream publishers, use ``Publisher/zip(_:_:_:)-67czn``.
    ///
    /// In this example, as ``Publisher/merge(with:_:_:_:)`` receives input from the upstream publishers, it republishes the interleaved elements to the downstream:
    ///
    ///      let pubA = PassthroughSubject<Int, Never>()
    ///      let pubB = PassthroughSubject<Int, Never>()
    ///      let pubC = PassthroughSubject<Int, Never>()
    ///      let pubD = PassthroughSubject<Int, Never>()
    ///      let pubE = PassthroughSubject<Int, Never>()
    ///
    ///      cancellable = pubA
    ///          .merge(with: pubB, pubC, pubD, pubE)
    ///          .sink { print("\($0)", terminator: " " ) }
    ///
    ///      pubA.send(1)
    ///      pubB.send(40)
    ///      pubC.send(90)
    ///      pubD.send(-1)
    ///      pubE.send(33)
    ///      pubA.send(2)
    ///      pubB.send(50)
    ///      pubC.send(100)
    ///      pubD.send(-2)
    ///      pubE.send(33)
    ///
    ///      // Prints: "1 40 90 -1 33 2 50 100 -2 33"
    ///
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E>(with b: B, _ c: C, _ d: D, _ e: E) -> Publishers.Merge5<Self, B, C, D, E> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, Self.Failure == B.Failure, Self.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output {
        Publishers.Merge5(self, b, c, d, e)
    }

    /// Combines elements from this publisher with those from five other publishers, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:_:_:_:_:_:)`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:_:_:)-7mt86``.
    /// To combine elements from multiple upstream publishers, use ``Publisher/zip(_:_:_:)-67czn``.
    ///
    /// In this example, as ``Publisher/merge(with:_:_:_:_:_:)`` receives input from the upstream publishers, it republishes the interleaved elements to the downstream:
    ///
    ///     let pubA = PassthroughSubject<Int, Never>()
    ///     let pubB = PassthroughSubject<Int, Never>()
    ///     let pubC = PassthroughSubject<Int, Never>()
    ///     let pubD = PassthroughSubject<Int, Never>()
    ///     let pubE = PassthroughSubject<Int, Never>()
    ///     let pubF = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pubA
    ///         .merge(with: pubB, pubC, pubD, pubE, pubF)
    ///         .sink { print("\($0)", terminator: " " ) }
    ///
    ///     pubA.send(1)
    ///     pubB.send(40)
    ///     pubC.send(90)
    ///     pubD.send(-1)
    ///     pubE.send(33)
    ///     pubF.send(44)
    ///
    ///     pubA.send(2)
    ///     pubB.send(50)
    ///     pubC.send(100)
    ///     pubD.send(-2)
    ///     pubE.send(33)
    ///     pubF.send(33)
    ///
    ///     //Prints: "1 40 90 -1 33 44 2 50 100 -2 33 33"
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E, F>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Publishers.Merge6<Self, B, C, D, E, F> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, Self.Failure == B.Failure, Self.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output {
        Publishers.Merge6(self, b, c, d, e, f)
    }

    /// Combines elements from this publisher with those from six other publishers, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:_:_:_:_:_:)`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:_:_:)-7mt86``.
    /// To combine elements from multiple upstream publishers, use ``Publisher/zip(_:_:_:)-67czn``.
    ///
    /// In this example, as ``Publisher/merge(with:_:_:_:_:_:)`` receives input from the upstream publishers; it republishes the interleaved elements to the downstream:
    ///
    ///     let pubA = PassthroughSubject<Int, Never>()
    ///     let pubB = PassthroughSubject<Int, Never>()
    ///     let pubC = PassthroughSubject<Int, Never>()
    ///     let pubD = PassthroughSubject<Int, Never>()
    ///     let pubE = PassthroughSubject<Int, Never>()
    ///     let pubF = PassthroughSubject<Int, Never>()
    ///     let pubG = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pubA
    ///         .merge(with: pubB, pubC, pubD, pubE, pubE, pubG)
    ///         .sink { print("\($0)", terminator: " " ) }
    ///
    ///     pubA.send(1)
    ///     pubB.send(40)
    ///     pubC.send(90)
    ///     pubD.send(-1)
    ///     pubE.send(33)
    ///     pubF.send(44)
    ///     pubG.send(54)
    ///
    ///     pubA.send(2)
    ///     pubB.send(50)
    ///     pubC.send(100)
    ///     pubD.send(-2)
    ///     pubE.send(33)
    ///     pubF.send(33)
    ///     pubG.send(54)
    ///
    ///     //Prints: "1 40 90 -1 33 44 54 2 50 100 -2 33 33 54"
    ///
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    ///   - g: A seventh publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E, F, G>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) -> Publishers.Merge7<Self, B, C, D, E, F, G> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, Self.Failure == B.Failure, Self.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output {
        Publishers.Merge7(self, b, c, d, e, f, g)
    }

    /// Combines elements from this publisher with those from seven other publishers, delivering an interleaved sequence of elements.
    ///
    /// Use ``Publisher/merge(with:_:_:_:_:_:_:)`` when you want to receive a new element whenever any of the upstream publishers emits an element. To receive tuples of the most-recent value from all the upstream publishers whenever any of them emit a value, use ``Publisher/combineLatest(_:_:_:)-7mt86``.
    /// To combine elements from multiple upstream publishers, use ``Publisher/zip(_:_:_:)-67czn``.
    ///
    /// In this example, as ``Publisher/merge(with:_:_:_:_:_:_:)`` receives input from the upstream publishers, it republishes the interleaved elements to the downstream:
    ///
    ///     let pubA = PassthroughSubject<Int, Never>()
    ///     let pubB = PassthroughSubject<Int, Never>()
    ///     let pubC = PassthroughSubject<Int, Never>()
    ///     let pubD = PassthroughSubject<Int, Never>()
    ///     let pubE = PassthroughSubject<Int, Never>()
    ///     let pubF = PassthroughSubject<Int, Never>()
    ///     let pubG = PassthroughSubject<Int, Never>()
    ///     let pubH = PassthroughSubject<Int, Never>()
    ///
    ///     cancellable = pubA
    ///         .merge(with: pubB, pubC, pubD, pubE, pubF, pubG, pubH)
    ///         .sink { print("\($0)", terminator: " " ) }
    ///
    ///     pubA.send(1)
    ///     pubB.send(40)
    ///     pubC.send(90)
    ///     pubD.send(-1)
    ///     pubE.send(33)
    ///     pubF.send(44)
    ///     pubG.send(54)
    ///     pubH.send(1000)
    ///
    ///     pubA.send(2)
    ///     pubB.send(50)
    ///     pubC.send(100)
    ///     pubD.send(-2)
    ///     pubE.send(33)
    ///     pubF.send(33)
    ///     pubG.send(54)
    ///     pubH.send(1001)
    ///
    ///     //Prints: "1 40 90 -1 33 44 54 1000 2 50 100 -2 33 33 54 1001"
    ///
    /// The merged publisher continues to emit elements until all upstream publishers finish.
    /// If an upstream publisher produces an error, the merged publisher fails with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    ///   - g: A seventh publisher.
    ///   - h: An eighth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits an event.
    public func merge<B, C, D, E, F, G, H>(with b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) -> Publishers.Merge8<Self, B, C, D, E, F, G, H> where B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher, Self.Failure == B.Failure, Self.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output, G.Failure == H.Failure, G.Output == H.Output {
        Publishers.Merge8(self, b, c, d, e, f, g, h)
    }

    /// Combines elements from this publisher with those from another publisher of the same type, delivering an interleaved sequence of elements.
    ///
    /// - Parameter other: Another publisher of this publisher’s type.
    /// - Returns: A publisher that emits an event when either upstream publisher emits an event.
    public func merge(with other: Self) -> Publishers.MergeMany<Self> {
        Publishers.MergeMany([self, other])
    }
}

// MARK: - Merge Publishers

extension Publishers {
    /// A publisher created by applying the merge function to two upstream publishers.
    public struct Merge<A, B>: Publisher where A: Publisher, B: Publisher, A.Failure == B.Failure, A.Output == B.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output
        
        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure
        
        /// A publisher to merge.
        public let a: A
        
        /// A second publisher to merge.
        public let b: B
        
        /// Creates a publisher created by applying the merge function to two upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b
        }
        
        public func receive<S>(subscriber: S) where S: Subscriber, B.Failure == S.Failure, B.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 2)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
        }
        
        public func merge<P>(with p: P) -> Publishers.Merge3<A, B, P> where P: Publisher, B.Failure == P.Failure, B.Output == P.Output {
            Merge3(a, b, p)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge4<A, B, Z, Y> where Z: Publisher, Y: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            Merge4(a, b, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge5<A, B, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            Merge5(a, b, z, y, x)
        }

        public func merge<Z, Y, X, W>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge6<A, B, Z, Y, X, W> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output {
            Merge6(a, b, z, y, x, w)
        }

        public func merge<Z, Y, X, W, V>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V) -> Publishers.Merge7<A, B, Z, Y, X, W, V> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output, W.Failure == V.Failure, W.Output == V.Output {
            Merge7(a, b, z, y, x, w, v)
        }

        public func merge<Z, Y, X, W, V, U>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V, _ u: U) -> Publishers.Merge8<A, B, Z, Y, X, W, V, U> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, U: Publisher, B.Failure == Z.Failure, B.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output, W.Failure == V.Failure, W.Output == V.Output, V.Failure == U.Failure, V.Output == U.Output {
            Merge8(a, b, z, y, x, w, v, u)
        }
    }
    
    /// A publisher created by applying the merge function to three upstream publishers.
    public struct Merge3<A, B, C>: Publisher where A: Publisher, B: Publisher, C: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to merge.
        public let a: A

        /// A second publisher to merge.
        public let b: B

        /// A third publisher to merge.
        public let c: C

        /// Creates a publisher created by applying the merge function to three upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        ///   - c: A third publisher to merge.
        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<S>(subscriber: S) where S: Subscriber, C.Failure == S.Failure, C.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 3)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
            c.subscribe(Inner.Side(index: 2, merger: merger))
        }
        
        public func merge<P>(with other: P) -> Publishers.Merge4<A, B, C, P> where P: Publisher, C.Failure == P.Failure, C.Output == P.Output {
            Merge4(a, b, c, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge5<A, B, C, Z, Y> where Z: Publisher, Y: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            Merge5(a, b, c, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge6<A, B, C, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            Merge6(a, b, c, z, y, x)
        }

        public func merge<Z, Y, X, W>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge7<A, B, C, Z, Y, X, W> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output {
            Merge7(a, b, c, z, y, x, w)
        }

        public func merge<Z, Y, X, W, V>(with z: Z, _ y: Y, _ x: X, _ w: W, _ v: V) -> Publishers.Merge8<A, B, C, Z, Y, X, W, V> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, V: Publisher, C.Failure == Z.Failure, C.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output, W.Failure == V.Failure, W.Output == V.Output {
            Merge8(a, b, c, z, y, x, w, v)
        }
    }

    /// A publisher created by applying the merge function to four upstream publishers.
    public struct Merge4<A, B, C, D>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to merge.
        public let a: A

        /// A second publisher to merge.
        public let b: B

        /// A third publisher to merge.
        public let c: C

        /// A fourth publisher to merge.
        public let d: D

        /// Creates a publisher created by applying the merge function to four upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        ///   - c: A third publisher to merge.
        ///   - d: A fourth publisher to merge.
        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<S>(subscriber: S) where S: Subscriber, D.Failure == S.Failure, D.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 4)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
            c.subscribe(Inner.Side(index: 2, merger: merger))
            d.subscribe(Inner.Side(index: 3, merger: merger))
        }

        public func merge<P>(with other: P) -> Publishers.Merge5<A, B, C, D, P> where P: Publisher, D.Failure == P.Failure, D.Output == P.Output {
            Merge5(a, b, c, d, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge6<A, B, C, D, Z, Y> where Z: Publisher, Y: Publisher, D.Failure == Z.Failure, D.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            Merge6(a, b, c, d, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge7<A, B, C, D, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, D.Failure == Z.Failure, D.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            Merge7(a, b, c, d, z, y, x)
        }

        public func merge<Z, Y, X, W>(with z: Z, _ y: Y, _ x: X, _ w: W) -> Publishers.Merge8<A, B, C, D, Z, Y, X, W> where Z: Publisher, Y: Publisher, X: Publisher, W: Publisher, D.Failure == Z.Failure, D.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output, X.Failure == W.Failure, X.Output == W.Output {
            Merge8(a, b, c, d, z, y, x, w)
        }
    }

    /// A publisher created by applying the merge function to five upstream publishers.
    public struct Merge5<A, B, C, D, E>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to merge.
        public let a: A

        /// A second publisher to merge.
        public let b: B

        /// A third publisher to merge.
        public let c: C

        /// A fourth publisher to merge.
        public let d: D

        /// A fifth publisher to merge.
        public let e: E

        /// Creates a publisher created by applying the merge function to five upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        ///   - c: A third publisher to merge.
        ///   - d: A fourth publisher to merge.
        ///   - e: A fifth publisher to merge.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
        }

        public func receive<S>(subscriber: S) where S: Subscriber, E.Failure == S.Failure, E.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 5)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
            c.subscribe(Inner.Side(index: 2, merger: merger))
            d.subscribe(Inner.Side(index: 3, merger: merger))
            e.subscribe(Inner.Side(index: 4, merger: merger))
        }

        public func merge<P>(with other: P) -> Publishers.Merge6<A, B, C, D, E, P> where P: Publisher, E.Failure == P.Failure, E.Output == P.Output {
            Merge6(a, b, c, d, e, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge7<A, B, C, D, E, Z, Y> where Z: Publisher, Y: Publisher, E.Failure == Z.Failure, E.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            Merge7(a, b, c, d, e, z, y)
        }

        public func merge<Z, Y, X>(with z: Z, _ y: Y, _ x: X) -> Publishers.Merge8<A, B, C, D, E, Z, Y, X> where Z: Publisher, Y: Publisher, X: Publisher, E.Failure == Z.Failure, E.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output, Y.Failure == X.Failure, Y.Output == X.Output {
            Merge8(a, b, c, d, e, z, y, x)
        }
    }

    /// A publisher created by applying the merge function to six upstream publishers.
    public struct Merge6<A, B, C, D, E, F>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to merge.
        public let a: A

        /// A second publisher to merge.
        public let b: B

        /// A third publisher to merge.
        public let c: C

        /// A fourth publisher to merge.
        public let d: D

        /// A fifth publisher to merge.
        public let e: E

        /// A sixth publisher to merge.
        public let f: F

        /// publisher created by applying the merge function to six upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        ///   - c: A third publisher to merge.
        ///   - d: A fourth publisher to merge.
        ///   - e: A fifth publisher to merge.
        ///   - f: A sixth publisher to merge.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
        }

        public func receive<S>(subscriber: S) where S: Subscriber, F.Failure == S.Failure, F.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 6)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
            c.subscribe(Inner.Side(index: 2, merger: merger))
            d.subscribe(Inner.Side(index: 3, merger: merger))
            e.subscribe(Inner.Side(index: 4, merger: merger))
            f.subscribe(Inner.Side(index: 5, merger: merger))
        }

        public func merge<P>(with other: P) -> Publishers.Merge7<A, B, C, D, E, F, P> where P: Publisher, F.Failure == P.Failure, F.Output == P.Output {
            Merge7(a, b, c, d, e, f, other)
        }

        public func merge<Z, Y>(with z: Z, _ y: Y) -> Publishers.Merge8<A, B, C, D, E, F, Z, Y> where Z: Publisher, Y: Publisher, F.Failure == Z.Failure, F.Output == Z.Output, Z.Failure == Y.Failure, Z.Output == Y.Output {
            Merge8(a, b, c, d, e, f, z, y)
        }
    }

    /// A publisher created by applying the merge function to seven upstream publishers.
    public struct Merge7<A, B, C, D, E, F, G>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to merge.
        public let a: A

        /// A second publisher to merge.
        public let b: B

        /// A third publisher to merge.
        public let c: C

        /// A fourth publisher to merge.
        public let d: D

        /// A fifth publisher to merge.
        public let e: E

        /// A sixth publisher to merge.
        public let f: F

        /// An seventh publisher to merge.
        public let g: G

        /// Creates a publisher created by applying the merge function to seven upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        ///   - c: A third publisher to merge.
        ///   - d: A fourth publisher to merge.
        ///   - e: A fifth publisher to merge.
        ///   - f: A sixth publisher to merge.
        ///   - g: An seventh publisher to merge.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
        }

        public func receive<S>(subscriber: S) where S: Subscriber, G.Failure == S.Failure, G.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 7)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
            c.subscribe(Inner.Side(index: 2, merger: merger))
            d.subscribe(Inner.Side(index: 3, merger: merger))
            e.subscribe(Inner.Side(index: 4, merger: merger))
            f.subscribe(Inner.Side(index: 5, merger: merger))
            g.subscribe(Inner.Side(index: 6, merger: merger))
        }

        public func merge<P>(with other: P) -> Publishers.Merge8<A, B, C, D, E, F, G, P> where P: Publisher, G.Failure == P.Failure, G.Output == P.Output {
            Merge8(a, b, c, d, e, f, g, other)
        }
    }

    /// A publisher created by applying the merge function to eight upstream publishers.
    public struct Merge8<A, B, C, D, E, F, G, H>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, H: Publisher, A.Failure == B.Failure, A.Output == B.Output, B.Failure == C.Failure, B.Output == C.Output, C.Failure == D.Failure, C.Output == D.Output, D.Failure == E.Failure, D.Output == E.Output, E.Failure == F.Failure, E.Output == F.Output, F.Failure == G.Failure, F.Output == G.Output, G.Failure == H.Failure, G.Output == H.Output {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = A.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = A.Failure

        /// A publisher to merge.
        public let a: A

        /// A second publisher to merge.
        public let b: B

        /// A third publisher to merge.
        public let c: C

        /// A fourth publisher to merge.
        public let d: D

        /// A fifth publisher to merge.
        public let e: E

        /// A sixth publisher to merge.
        public let f: F

        /// An seventh publisher to merge.
        public let g: G

        /// A eighth publisher to merge.
        public let h: H

        /// Creates a publisher created by applying the merge function to eight upstream publishers.
        /// - Parameters:
        ///   - a: A publisher to merge
        ///   - b: A second publisher to merge.
        ///   - c: A third publisher to merge.
        ///   - d: A fourth publisher to merge.
        ///   - e: A fifth publisher to merge.
        ///   - f: A sixth publisher to merge.
        ///   - g: An seventh publisher to merge.
        ///   - h: An eighth publisher to merge.
        public init(_ a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F, _ g: G, _ h: H) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
            self.h = h
        }

        public func receive<S>(subscriber: S) where S: Subscriber, H.Failure == S.Failure, H.Output == S.Input {
            typealias Inner = _Merged<A.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: 8)
            subscriber.receive(subscription: merger)
            a.subscribe(Inner.Side(index: 0, merger: merger))
            b.subscribe(Inner.Side(index: 1, merger: merger))
            c.subscribe(Inner.Side(index: 2, merger: merger))
            d.subscribe(Inner.Side(index: 3, merger: merger))
            e.subscribe(Inner.Side(index: 4, merger: merger))
            f.subscribe(Inner.Side(index: 5, merger: merger))
            g.subscribe(Inner.Side(index: 6, merger: merger))
            h.subscribe(Inner.Side(index: 7, merger: merger))
        }
    }
    
    /// A publisher created by applying the merge function to an arbitrary number of upstream publishers.
    public struct MergeMany<Upstream>: Publisher where Upstream: Publisher {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publishers' common output type.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publishers' common failure type.
        public typealias Failure = Upstream.Failure

        /// The array of upstream publishers that this publisher merges together.
        public let publishers: [Upstream]

        /// Creates a publisher created by applying the merge function to an arbitrary number of upstream publishers.
        /// - Parameter upstream: A variadic parameter containing zero or more publishers to merge with this publisher.
        public init(_ upstream: Upstream...) {
            publishers = upstream
        }

        /// Creates a publisher created by applying the merge function to a sequence of upstream publishers.
        /// - Parameter upstream: A sequence containing zero or more publishers to merge with this publisher.
        public init<S>(_ upstream: S) where Upstream == S.Element, S: Swift.Sequence {
            publishers = Array(upstream)
        }

        public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            typealias Inner = _Merged<Upstream.Output, Failure, S>
            let merger = Inner(downstream: subscriber, count: publishers.count)
            subscriber.receive(subscription: merger)
            for (index, publisher) in publishers.enumerated() {
                publisher.subscribe(Inner.Side(index: index, merger: merger))
            }
        }

        public func merge(with other: Upstream) -> Publishers.MergeMany<Upstream> {
            MergeMany(publishers + [other])
        }
    }
}

// MARK: - Equatable conformances

extension Publishers.Merge: Equatable where A: Equatable, B: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality..
    /// - Returns: `true` if the two merging - rhs: Another merging publisher to compare for equality.
    public static func == (lhs: Publishers.Merge<A, B>, rhs: Publishers.Merge<A, B>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b
    }
}

extension Publishers.Merge3: Equatable where A: Equatable, B: Equatable, C: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers; otherwise `false`.
    public static func == (lhs: Publishers.Merge3<A, B, C>, rhs: Publishers.Merge3<A, B, C>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c
    }
}

extension Publishers.Merge4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers; otherwise `false`.
    public static func == (lhs: Publishers.Merge4<A, B, C, D>, rhs: Publishers.Merge4<A, B, C, D>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d
    }
}

extension Publishers.Merge5: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers; otherwise `false`.
    public static func == (lhs: Publishers.Merge5<A, B, C, D, E>, rhs: Publishers.Merge5<A, B, C, D, E>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e
    }
}

extension Publishers.Merge6: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers; otherwise `false`.
    public static func == (lhs: Publishers.Merge6<A, B, C, D, E, F>, rhs: Publishers.Merge6<A, B, C, D, E, F>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f
    }
}

extension Publishers.Merge7: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers; otherwise `false`.
    public static func == (lhs: Publishers.Merge7<A, B, C, D, E, F, G>, rhs: Publishers.Merge7<A, B, C, D, E, F, G>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g
    }
}

extension Publishers.Merge8: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable, H: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    ///
    /// - Parameters:
    ///   - lhs: A merging publisher to compare for equality.
    ///   - rhs: Another merging publisher to compare for equality.
    /// - Returns: `true` if the two merging publishers have equal source publishers; otherwise `false`.
    public static func == (lhs: Publishers.Merge8<A, B, C, D, E, F, G, H>, rhs: Publishers.Merge8<A, B, C, D, E, F, G, H>) -> Bool {
        lhs.a == rhs.a && lhs.b == rhs.b && lhs.c == rhs.c && lhs.d == rhs.d && lhs.e == rhs.e && lhs.f == rhs.f && lhs.g == rhs.g && lhs.h == rhs.h
    }
}

extension Publishers.MergeMany: Equatable where Upstream: Equatable {
    /// Returns a Boolean value that indicates whether two publishers are equivalent.
    /// - Parameters:
    ///   - lhs: A `MergeMany` publisher to compare for equality.
    ///   - rhs: Another `MergeMany` publisher to compare for equality.
    /// - Returns: `true` if the publishers have equal `publishers` properties; otherwise `false`.
    public static func == (lhs: Publishers.MergeMany<Upstream>, rhs: Publishers.MergeMany<Upstream>) -> Bool {
        lhs.publishers == rhs.publishers
    }
}

// MARK: - _Merge

extension Publishers {
    fileprivate class _Merged<Input, Failure, Downstream> where Downstream: Subscriber, Input == Downstream.Input, Failure == Downstream.Failure {
        let downstream: Downstream
        var demand = Subscribers.Demand.none
        var terminated = false
        let count: Int
        var upstreamFinished = 0
        var finished = false
        var subscriptions: [Subscription?]
        var buffers: [Input?]
        let lock = UnfairLock.allocate()
        let downstreamLock = UnfairRecursiveLock.allocate()
        var recursive = false
        var pending = Subscribers.Demand.none
        
        init(downstream: Downstream, count: Int) {
            self.downstream = downstream
            self.count = count
            subscriptions = .init(repeating: nil, count: count)
            buffers = .init(repeating: nil, count: count)
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
    }
}

extension Publishers._Merged: Subscription {
    func request(_ demand: Subscribers.Demand) {
        lock.lock()
        guard !terminated,
              !finished,
              demand != .none,
              self.demand != .unlimited else {
            lock.unlock()
            return
        }
        guard !recursive else {
            pending = pending + demand
            lock.unlock()
            return
        }
        if demand == .unlimited {
            self.demand = .unlimited
            let buffers = buffers
            self.buffers = Array(repeating: nil, count: buffers.count)
            let subscriptions = subscriptions
            let upstreamFinished = upstreamFinished
            let count = count
            lock.unlock()
            buffers.forEach { input in
                guard let input else {
                    return
                }
                guardedApplyDownstream { downstream in
                    _ = downstream.receive(input)
                }
            }
            if upstreamFinished == count {
                guardedBecomeTerminal()
                guardedApplyDownstream { downstream in
                    downstream.receive(completion: .finished)
                }
            } else {
                for subscription in subscriptions {
                    subscription?.request(.unlimited)
                }
            }
        } else {
            self.demand = self.demand + demand
            var newBuffers: [Input] = []
            var newSubscrptions: [Subscription?] = []
            for (index, buffer) in buffers.enumerated() {
                guard self.demand != .zero else {
                    break
                }
                guard let buffer else {
                    continue
                }
                buffers[index] = nil
                if self.demand != .unlimited {
                    self.demand -= 1
                }
                newBuffers.append(buffer)
                newSubscrptions.append(subscriptions[index])
            }
            let newFinished: Bool
            if upstreamFinished == count {
                if buffers.allSatisfy({ $0 == nil }) {
                    newFinished = true
                    finished = true
                } else {
                    newFinished = false
                }
            } else {
                newFinished = false
            }
            lock.unlock()
            var newDemand = Subscribers.Demand.none
            for buffer in newBuffers {
                let demandResult = guardedApplyDownstream { downstream in
                    downstream.receive(buffer)
                }
                newDemand += demandResult
            }
            lock.lock()
            newDemand = newDemand + pending
            pending = .none
            lock.unlock()
            if newFinished {
                guardedBecomeTerminal()
                guardedApplyDownstream { downstream in
                    downstream.receive(completion: .finished)
                }
            } else {
                if newDemand != .none {
                    lock.lock()
                    self.demand += newDemand
                    lock.unlock()
                }
                for subscrption in newSubscrptions {
                    subscrption?.request(.max(1))
                }
            }
        }
    }
    
    func cancel() {
        guardedBecomeTerminal()
    }
}

extension Publishers._Merged {
    func receive(subscription: Subscription, _ index: Int) {
        lock.lock()
        guard !terminated, subscriptions[index] == nil else {
            lock.unlock()
            subscription.cancel()
            return
        }
        subscriptions[index] = subscription
        let demand = demand == .unlimited ? demand : .max(1)
        lock.unlock()
        subscription.request(demand)
    }
    
    func receive(_ input: Input, _ index: Int) -> Subscribers.Demand {
        lock.lock()
        guard demand != .unlimited else {
            lock.unlock()
            return guardedApplyDownstream { downstream in
                downstream.receive(input)
            }
        }
        if demand == .none {
            buffers[index] = input
            lock.unlock()
            return .none
        } else {
            lock.unlock()
            let result = guardedApplyDownstream { downstream in
                downstream.receive(input)
            }
            lock.lock()
            demand = result + pending + demand - 1
            pending = .none
            lock.unlock()
            return .max(1)
        }
    }
    
    func receive(completion: Subscribers.Completion<Failure>, _ index: Int) {
        switch completion {
        case .finished:
            lock.lock()
            upstreamFinished += 1
            subscriptions[index] = nil
            if upstreamFinished == count, buffers.allSatisfy({ $0 == nil }) {
                finished = true
                lock.unlock()
                guardedBecomeTerminal()
                guardedApplyDownstream { downstream in
                    downstream.receive(completion: .finished)
                }
            } else {
                lock.unlock()
            }
        case .failure:
            lock.lock()
            let terminated = terminated
            lock.unlock()
            if !terminated {
                guardedBecomeTerminal()
                guardedApplyDownstream { downstream in
                    downstream.receive(completion: completion)
                }
            }
        }
    }
    
    private func guardedApplyDownstream<Result>(_ block: (Downstream) -> Result) -> Result {
        lock.lock()
        recursive = true
        lock.unlock()
        downstreamLock.lock()
        let result = block(downstream)
        downstreamLock.unlock()
        lock.lock()
        recursive = false
        lock.unlock()
        return result
    }
    
    private func guardedBecomeTerminal() {
        lock.lock()
        terminated = true
        let subscriptions = subscriptions
        self.subscriptions = Array(repeating: nil, count: subscriptions.count)
        buffers = Array(repeating: nil, count: buffers.count)
        lock.unlock()
        for subscription in subscriptions {
            subscription?.cancel()
        }
    }
}

extension Publishers._Merged {
    struct Side {
        let index: Int
        let merger: Publishers._Merged<Input, Failure, Downstream>
        let combineIdentifier: CombineIdentifier
        
        init(index: Int, merger: Publishers._Merged<Input, Failure, Downstream>) {
            self.index = index
            self.merger = merger
            combineIdentifier = CombineIdentifier()
        }
    }
}

extension Publishers._Merged.Side: Subscriber {
    func receive(subscription: Subscription) {
        merger.receive(subscription: subscription, index)
    }
    
    func receive(_ input: Input) -> Subscribers.Demand {
        merger.receive(input, index)
    }
    
    func receive(completion: Subscribers.Completion<Failure>) {
        merger.receive(completion: completion, index)
    }
}

extension Publishers._Merged: CustomStringConvertible {
    var description: String { "Merge" }
}

extension Publishers._Merged.Side: CustomStringConvertible {
    var description: String { "Merge" }
}

extension Publishers._Merged: CustomPlaygroundDisplayConvertible {
    var playgroundDescription: Any { description }
}

extension Publishers._Merged.Side: CustomPlaygroundDisplayConvertible {
    var playgroundDescription: Any { description }
}

extension Publishers._Merged: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension Publishers._Merged.Side: CustomReflectable {
    var customMirror: Mirror {
        Mirror(self, children: ["parentSubscription": merger.combineIdentifier])
    }
}
