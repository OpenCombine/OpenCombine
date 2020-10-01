//
//  Record.swift
//  
//
//  Created by Sergej Jaskiewicz on 12.11.2019.
//

/// A publisher that allows for recording a series of inputs and a completion for later
/// playback to each subscriber.
public struct Record<Output, Failure: Error>: Publisher {

    /// The recorded output and completion.
    public let recording: Recording

    /// Creates a publisher to interactively record a series of outputs and a completion.
    ///
    /// - Parameter record: A recording instance that can be retrieved after completion
    ///   to create new record publishers to replay the recording.
    public init(record: (inout Recording) -> Void) {
        var recording = Recording()
        record(&recording)
        self.init(recording: recording)
    }

    /// Creates a record publisher from an existing recording.
    ///
    /// - Parameter recording: A previously-recorded recording of published elements
    ///   and a completion.
    public init(recording: Recording) {
        self.recording = recording
    }

    /// Creates a record publisher to publish the provided elements, followed by
    /// the provided completion value.
    ///
    /// - Parameters:
    ///   - output: An array of output elements to publish.
    ///   - completion: The completion value with which to end publishing.
    public init(output: [Output], completion: Subscribers.Completion<Failure>) {
        self.init(recording: Recording(output: output, completion: completion))
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
        if recording.output.isEmpty {
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: recording.completion)
        } else {
            let inner = Inner(downstream: subscriber,
                              sequence: recording.output,
                              completion: recording.completion)
            subscriber.receive(subscription: inner)
        }
    }

    /// A recorded sequence of outputs, followed by a completion value.
    public struct Recording {

        public typealias Input = Output

        private enum State {
            case input
            case complete
        }

        private var state: State

        /// The output which will be sent to a `Subscriber`.
        public private(set) var output: [Output]

        /// The completion which will be sent to a `Subscriber`.
        public private(set) var completion: Subscribers.Completion<Failure>

        /// Set up a recording in a state ready to receive output.
        public init() {
            state = .input
            output = []
            completion = .finished
        }

        /// Set up a complete recording with the specified output and completion.
        public init(output: [Output],
                    completion: Subscribers.Completion<Failure> = .finished) {
            self.state = .complete
            self.output = output
            self.completion = completion
        }

        /// Add an output to the recording.
        ///
        /// A `fatalError` will be raised if output is added after adding completion.
        public mutating func receive(_ input: Input) {
            precondition(state == .input,
                         "Receiving values after completion is not allowed")
            output.append(input)
        }

        /// Add a completion to the recording.
        ///
        /// A `fatalError` will be raised if more than one completion is added.
        public mutating func receive(completion: Subscribers.Completion<Failure>) {
            precondition(state == .input,
                         "Receiving completion more than once is not allowed")
            self.completion = completion
            self.state = .complete
        }
    }
}

extension Record: Codable where Output: Codable, Failure: Codable {}

extension Record.Recording: Codable where Output: Codable, Failure: Codable {

    private enum CodingKeys: String, CodingKey {
        case output = "output"
        case completion = "completion"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let output = try container.decode([Output].self, forKey: .output)
        let completion = try container.decode(Subscribers.Completion<Failure>.self,
                                              forKey: .completion)
        self.init(output: output, completion: completion)
    }

    public func encode(into encoder: Encoder) throws {
        try encode(to: encoder)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(output, forKey: .output)
        try container.encode(completion, forKey: .completion)
    }
}

extension Record {

    // This class is almost the same as Publishers.Sequence.Inner
    // despite some small details.
    private final class Inner<Downstream: Subscriber>
        : Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Failure
    {
        // NOTE: This class has been audited for thread-safety

        private var sequence: [Output]?
        private let completion: Subscribers.Completion<Failure>
        private var downstream: Downstream?
        private var iterator: IndexingIterator<[Output]>
        private var next: Output?
        private var pendingDemand = Subscribers.Demand.none
        private var recursion = false
        private var lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream,
                         sequence: [Output],
                         completion: Subscribers.Completion<Failure>) {
            self.sequence = sequence
            self.completion = completion
            self.downstream = downstream
            self.iterator = sequence.makeIterator()
            next = iterator.next()
        }

        deinit {
            lock.deallocate()
        }

        var description: String {
            lock.lock()
            defer { lock.unlock() }
            return sequence.map { $0.description } ?? "Cancelled Events"
        }

        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("sequence", sequence ?? [Output]()),
                ("completion", completion)
            ]
            return Mirror(self, children: children)
        }

        var playgroundDescription: Any { return description }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard downstream != nil else {
                lock.unlock()
                return
            }
            pendingDemand += demand
            if recursion {
                lock.unlock()
                return
            }

            while let downstream = self.downstream, pendingDemand > 0 {
                if let current = self.next {
                    pendingDemand -= 1
                    let next = iterator.next()
                    recursion = true
                    lock.unlock()
                    let additionalDemand = downstream.receive(current)
                    lock.lock()
                    recursion = false
                    pendingDemand += additionalDemand
                    self.next = next
                }

                if next == nil {
                    self.downstream = nil
                    self.sequence = nil
                    lock.unlock()
                    downstream.receive(completion: completion)
                    return
                }
            }

            lock.unlock()
        }

        func cancel() {
            lock.lock()
            downstream = nil
            sequence = nil
            lock.unlock()
        }
    }
}
