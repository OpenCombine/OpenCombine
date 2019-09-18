//
//  Publishers.Share
//  
//
//  Created by Sergej Jaskiewicz on 18/09/2019.
//

extension Publisher {

    /// Returns a publisher as a class instance.
    ///
    /// The downstream subscriber receieves elements and completion states unchanged from
    /// the upstream publisher. Use this operator when you want to use
    /// reference semantics, such as storing a publisher instance in a property.
    ///
    /// - Returns: A class instance that republishes its upstream publisher.
    public func share() -> Publishers.Share<Self> {
        return .init(upstream: self)
    }
}


extension Publishers {

    /// A publisher implemented as a class, which otherwise behaves like its upstream
    /// publisher.
    public final class Share<Upstream: Publisher>: Publisher, Equatable {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        private var inner:
            Autoconnect<Multicast<Upstream, PassthroughSubject<Output, Failure>>>

        public let upstream: Upstream

        public init(upstream: Upstream) {
            inner = upstream.multicast(subject: .init()).autoconnect()
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            inner.subscribe(subscriber)
        }

        public static func == (lhs: Share, rhs: Share) -> Bool {
            return lhs === rhs
        }
    }
}
