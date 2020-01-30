// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  Publishers.Merge.swift.gyb
//  
//
//  Created by Sergej Jaskiewicz on 04/10/2019.
//

// swiftlint:disable generic_type_name
// swiftlint:disable vertical_parameter_alignment

// MARK: - Merge methods on Publisher

extension Publisher {

    /// Combines elements from this publisher with those from another publisher,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - other: Another publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        P: Publisher
    >(with other: P) -> Publishers.Merge<Self, P>
        where Failure == P.Failure, Output == P.Output
    {
        return .init(self, other)
    }
    /// Combines elements from this publisher with those from three other publishers,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        B: Publisher,
        C: Publisher
    >(with b: B,
         _ c: C) -> Publishers.Merge3<Self, B, C>
        where Failure == B.Failure, Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output
    {
        return .init(self, b, c)
    }
    /// Combines elements from this publisher with those from four other publishers,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        B: Publisher,
        C: Publisher,
        D: Publisher
    >(with b: B,
         _ c: C,
         _ d: D) -> Publishers.Merge4<Self, B, C, D>
        where Failure == B.Failure, Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output
    {
        return .init(self, b, c, d)
    }
    /// Combines elements from this publisher with those from five other publishers,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        B: Publisher,
        C: Publisher,
        D: Publisher,
        E: Publisher
    >(with b: B,
         _ c: C,
         _ d: D,
         _ e: E) -> Publishers.Merge5<Self, B, C, D, E>
        where Failure == B.Failure, Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output
    {
        return .init(self, b, c, d, e)
    }
    /// Combines elements from this publisher with those from six other publishers,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        B: Publisher,
        C: Publisher,
        D: Publisher,
        E: Publisher,
        F: Publisher
    >(with b: B,
         _ c: C,
         _ d: D,
         _ e: E,
         _ f: F) -> Publishers.Merge6<Self, B, C, D, E, F>
        where Failure == B.Failure, Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output,
              E.Failure == F.Failure, E.Output == F.Output
    {
        return .init(self, b, c, d, e, f)
    }
    /// Combines elements from this publisher with those from seven other publishers,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    ///   - g: A seventh publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        B: Publisher,
        C: Publisher,
        D: Publisher,
        E: Publisher,
        F: Publisher,
        G: Publisher
    >(with b: B,
         _ c: C,
         _ d: D,
         _ e: E,
         _ f: F,
         _ g: G) -> Publishers.Merge7<Self, B, C, D, E, F, G>
        where Failure == B.Failure, Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output,
              E.Failure == F.Failure, E.Output == F.Output,
              F.Failure == G.Failure, F.Output == G.Output
    {
        return .init(self, b, c, d, e, f, g)
    }
    /// Combines elements from this publisher with those from eight other publishers,
    /// delivering an interleaved sequence of elements.
    ///
    /// The merged publisher continues to emit elements until all upstream publishers
    /// finish. If an upstream publisher produces an error, the merged publisher fails
    /// with that error.
    ///
    /// - Parameters:
    ///   - b: A second publisher.
    ///   - c: A third publisher.
    ///   - d: A fourth publisher.
    ///   - e: A fifth publisher.
    ///   - f: A sixth publisher.
    ///   - g: A seventh publisher.
    ///   - h: An eighth publisher.
    /// - Returns: A publisher that emits an event when any upstream publisher emits
    ///   an event.
    public func merge<
        B: Publisher,
        C: Publisher,
        D: Publisher,
        E: Publisher,
        F: Publisher,
        G: Publisher,
        H: Publisher
    >(with b: B,
         _ c: C,
         _ d: D,
         _ e: E,
         _ f: F,
         _ g: G,
         _ h: H) -> Publishers.Merge8<Self, B, C, D, E, F, G, H>
        where Failure == B.Failure, Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output,
              E.Failure == F.Failure, E.Output == F.Output,
              F.Failure == G.Failure, F.Output == G.Output,
              G.Failure == H.Failure, G.Output == H.Output
    {
        return .init(self, b, c, d, e, f, g, h)
    }
}

extension Publisher {

    /// Combines elements from this publisher with those from another publisher of
    /// the same type, delivering an interleaved sequence of elements.
    ///
    /// - Parameter other: Another publisher of this publisher's type.
    /// - Returns: A publisher that emits an event when either upstream publisher emits
    ///   an event.
    public func merge(with other: Self) -> Publishers.MergeMany<Self> {
        return .init([self, other])
    }
}

// MARK: - Merge publishers

extension Publishers {

    /// A publisher created by applying the merge function to two upstream
    /// publishers.
    public struct Merge<A: Publisher,
                        B: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public init(
            _ a: A,
            _ b: B
        ) {
            self.a = a
            self.b = b
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 2)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            subscriber.receive(subscription: merged)
        }

        public func merge<
            P: Publisher
        >(with other: P) -> Publishers.Merge3<A, B, P>
        {
            return .init(a, b, other)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher
        >(with z: Z,
             _ y: Y) -> Publishers.Merge4<A, B, Z, Y>
        {
            return .init(a, b, z, y)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X) -> Publishers.Merge5<A, B, Z, Y, X>
        {
            return .init(a, b, z, y, x)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher,
            W: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X,
             _ w: W) -> Publishers.Merge6<A, B, Z, Y, X, W>
        {
            return .init(a, b, z, y, x, w)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher,
            W: Publisher,
            V: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X,
             _ w: W,
             _ v: V) -> Publishers.Merge7<A, B, Z, Y, X, W, V>
        {
            return .init(a, b, z, y, x, w, v)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher,
            W: Publisher,
            V: Publisher,
            U: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X,
             _ w: W,
             _ v: V,
             _ u: U) -> Publishers.Merge8<A, B, Z, Y, X, W, V, U>
        {
            return .init(a, b, z, y, x, w, v, u)
        }
    }

    /// A publisher created by applying the merge function to three upstream
    /// publishers.
    public struct Merge3<A: Publisher,
                         B: Publisher,
                         C: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public init(
            _ a: A,
            _ b: B,
            _ c: C
        ) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 3)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            c.subscribe(Merged.Side(index: 2, merger: merged))
            subscriber.receive(subscription: merged)
        }

        public func merge<
            P: Publisher
        >(with other: P) -> Publishers.Merge4<A, B, C, P>
        {
            return .init(a, b, c, other)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher
        >(with z: Z,
             _ y: Y) -> Publishers.Merge5<A, B, C, Z, Y>
        {
            return .init(a, b, c, z, y)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X) -> Publishers.Merge6<A, B, C, Z, Y, X>
        {
            return .init(a, b, c, z, y, x)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher,
            W: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X,
             _ w: W) -> Publishers.Merge7<A, B, C, Z, Y, X, W>
        {
            return .init(a, b, c, z, y, x, w)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher,
            W: Publisher,
            V: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X,
             _ w: W,
             _ v: V) -> Publishers.Merge8<A, B, C, Z, Y, X, W, V>
        {
            return .init(a, b, c, z, y, x, w, v)
        }
    }

    /// A publisher created by applying the merge function to four upstream
    /// publishers.
    public struct Merge4<A: Publisher,
                         B: Publisher,
                         C: Publisher,
                         D: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public init(
            _ a: A,
            _ b: B,
            _ c: C,
            _ d: D
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 4)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            c.subscribe(Merged.Side(index: 2, merger: merged))
            d.subscribe(Merged.Side(index: 3, merger: merged))
            subscriber.receive(subscription: merged)
        }

        public func merge<
            P: Publisher
        >(with other: P) -> Publishers.Merge5<A, B, C, D, P>
        {
            return .init(a, b, c, d, other)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher
        >(with z: Z,
             _ y: Y) -> Publishers.Merge6<A, B, C, D, Z, Y>
        {
            return .init(a, b, c, d, z, y)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X) -> Publishers.Merge7<A, B, C, D, Z, Y, X>
        {
            return .init(a, b, c, d, z, y, x)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher,
            W: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X,
             _ w: W) -> Publishers.Merge8<A, B, C, D, Z, Y, X, W>
        {
            return .init(a, b, c, d, z, y, x, w)
        }
    }

    /// A publisher created by applying the merge function to five upstream
    /// publishers.
    public struct Merge5<A: Publisher,
                         B: Publisher,
                         C: Publisher,
                         D: Publisher,
                         E: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public init(
            _ a: A,
            _ b: B,
            _ c: C,
            _ d: D,
            _ e: E
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 5)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            c.subscribe(Merged.Side(index: 2, merger: merged))
            d.subscribe(Merged.Side(index: 3, merger: merged))
            e.subscribe(Merged.Side(index: 4, merger: merged))
            subscriber.receive(subscription: merged)
        }

        public func merge<
            P: Publisher
        >(with other: P) -> Publishers.Merge6<A, B, C, D, E, P>
        {
            return .init(a, b, c, d, e, other)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher
        >(with z: Z,
             _ y: Y) -> Publishers.Merge7<A, B, C, D, E, Z, Y>
        {
            return .init(a, b, c, d, e, z, y)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher,
            X: Publisher
        >(with z: Z,
             _ y: Y,
             _ x: X) -> Publishers.Merge8<A, B, C, D, E, Z, Y, X>
        {
            return .init(a, b, c, d, e, z, y, x)
        }
    }

    /// A publisher created by applying the merge function to six upstream
    /// publishers.
    public struct Merge6<A: Publisher,
                         B: Publisher,
                         C: Publisher,
                         D: Publisher,
                         E: Publisher,
                         F: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output,
              E.Failure == F.Failure, E.Output == F.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public init(
            _ a: A,
            _ b: B,
            _ c: C,
            _ d: D,
            _ e: E,
            _ f: F
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 6)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            c.subscribe(Merged.Side(index: 2, merger: merged))
            d.subscribe(Merged.Side(index: 3, merger: merged))
            e.subscribe(Merged.Side(index: 4, merger: merged))
            f.subscribe(Merged.Side(index: 5, merger: merged))
            subscriber.receive(subscription: merged)
        }

        public func merge<
            P: Publisher
        >(with other: P) -> Publishers.Merge7<A, B, C, D, E, F, P>
        {
            return .init(a, b, c, d, e, f, other)
        }

        public func merge<
            Z: Publisher,
            Y: Publisher
        >(with z: Z,
             _ y: Y) -> Publishers.Merge8<A, B, C, D, E, F, Z, Y>
        {
            return .init(a, b, c, d, e, f, z, y)
        }
    }

    /// A publisher created by applying the merge function to seven upstream
    /// publishers.
    public struct Merge7<A: Publisher,
                         B: Publisher,
                         C: Publisher,
                         D: Publisher,
                         E: Publisher,
                         F: Publisher,
                         G: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output,
              E.Failure == F.Failure, E.Output == F.Output,
              F.Failure == G.Failure, F.Output == G.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public let g: G

        public init(
            _ a: A,
            _ b: B,
            _ c: C,
            _ d: D,
            _ e: E,
            _ f: F,
            _ g: G
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 7)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            c.subscribe(Merged.Side(index: 2, merger: merged))
            d.subscribe(Merged.Side(index: 3, merger: merged))
            e.subscribe(Merged.Side(index: 4, merger: merged))
            f.subscribe(Merged.Side(index: 5, merger: merged))
            g.subscribe(Merged.Side(index: 6, merger: merged))
            subscriber.receive(subscription: merged)
        }

        public func merge<
            P: Publisher
        >(with other: P) -> Publishers.Merge8<A, B, C, D, E, F, G, P>
        {
            return .init(a, b, c, d, e, f, g, other)
        }
    }

    /// A publisher created by applying the merge function to eight upstream
    /// publishers.
    public struct Merge8<A: Publisher,
                         B: Publisher,
                         C: Publisher,
                         D: Publisher,
                         E: Publisher,
                         F: Publisher,
                         G: Publisher,
                         H: Publisher>: Publisher
        where A.Failure == B.Failure, A.Output == B.Output,
              B.Failure == C.Failure, B.Output == C.Output,
              C.Failure == D.Failure, C.Output == D.Output,
              D.Failure == E.Failure, D.Output == E.Output,
              E.Failure == F.Failure, E.Output == F.Output,
              F.Failure == G.Failure, F.Output == G.Output,
              G.Failure == H.Failure, G.Output == H.Output
    {
        public typealias Output = A.Output

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public let e: E

        public let f: F

        public let g: G

        public let h: H

        public init(
            _ a: A,
            _ b: B,
            _ c: C,
            _ d: D,
            _ e: E,
            _ f: F,
            _ g: G,
            _ h: H
        ) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
            self.e = e
            self.f = f
            self.g = g
            self.h = h
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where A.Failure == Downstream.Failure,
                  A.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: 8)
            a.subscribe(Merged.Side(index: 0, merger: merged))
            b.subscribe(Merged.Side(index: 1, merger: merged))
            c.subscribe(Merged.Side(index: 2, merger: merged))
            d.subscribe(Merged.Side(index: 3, merger: merged))
            e.subscribe(Merged.Side(index: 4, merger: merged))
            f.subscribe(Merged.Side(index: 5, merger: merged))
            g.subscribe(Merged.Side(index: 6, merger: merged))
            h.subscribe(Merged.Side(index: 7, merger: merged))
            subscriber.receive(subscription: merged)
        }
    }
}

extension Publishers {
    public struct MergeMany<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        public let publishers: [Upstream]

        public init(_ upstream: Upstream...) {
            self.publishers = upstream
        }

        public init<UpstreamPublishers: Swift.Sequence>(_ upstream: UpstreamPublishers)
            where Upstream == UpstreamPublishers.Element
        {
            publishers = Array(upstream)
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            typealias Merged = _Merged<Output, Failure, Downstream>
            let merged = Merged(downstream: subscriber, count: publishers.count)
            for (i, upstream) in publishers.enumerated() {
                upstream.subscribe(Merged.Side(index: i, merger: merged))
            }
            subscriber.receive(subscription: merged)
        }

        public func merge(with other: Upstream) -> Publishers.MergeMany<Upstream> {
            var newPublishers = publishers
            newPublishers.append(other)
            return .init(newPublishers)
        }
    }
}

// MARK: - Equatable conformances

extension Publishers.Merge: Equatable
    where
        A: Equatable,
        B: Equatable {}

extension Publishers.Merge3: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable {}

extension Publishers.Merge4: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable,
        D: Equatable {}

extension Publishers.Merge5: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable,
        D: Equatable,
        E: Equatable {}

extension Publishers.Merge6: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable,
        D: Equatable,
        E: Equatable,
        F: Equatable {}

extension Publishers.Merge7: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable,
        D: Equatable,
        E: Equatable,
        F: Equatable,
        G: Equatable {}

extension Publishers.Merge8: Equatable
    where
        A: Equatable,
        B: Equatable,
        C: Equatable,
        D: Equatable,
        E: Equatable,
        F: Equatable,
        G: Equatable,
        H: Equatable {}

extension Publishers.MergeMany: Equatable
    where
        Upstream: Equatable {}
