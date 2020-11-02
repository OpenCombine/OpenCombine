//
//  URLSessionTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 13.12.2019.
//

// swiftlint:disable multiline_arguments

#if !WASI

import Foundation
import XCTest

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Prior to Swift 5.3 there were incompatibilities between Darwin Foundation and
// swift-corelibs-foundation that were making these tests impossible to build.
//
// Those were fixed in https://github.com/apple/swift-corelibs-foundation/pull/2587.
#if canImport(Darwin) || swift(>=5.3) // TEST_DISCOVERY_CONDITION

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class URLSessionTests: XCTestCase {

    private typealias TrackingSubscriber =
        TrackingSubscriberBase<(data: Data, response: URLResponse), URLError>

    private let testURL = URL(string: "https://github.com")!

    private let testRequest = URLRequest(url: URL(string: "https://github.com")!,
                                         cachePolicy: .reloadIgnoringCacheData,
                                         timeoutInterval: 42)

    private let testData = Data("test data".utf8)

    private let testResponse = URLResponse(url: URL(string: "https://example.com")!,
                                           mimeType: "text/markdown",
                                           expectedContentLength: 300,
                                           textEncodingName: "utf-8")

    private let testError = URLError(.cannotParseResponse, userInfo: ["a" : 1])

    private let unknownError = URLError(.unknown)

    func testDataTaskPublisherFromURL() {
        let publisher = makePublisher(TestURLSession(testDataTask: .init()), testURL)
        let expectedRequest = URLRequest(url: testURL)
        XCTAssertEqual(publisher.request, expectedRequest)
    }

    func testDataTaskPublisherFromRequest() {
        let publisher = makePublisher(TestURLSession(testDataTask: .init()), testRequest)
        XCTAssertEqual(publisher.request, testRequest)
    }

    func testReceiveNothing() {
        testReceiveResult(nil, nil, nil,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(unknownError))])
    }

    func testReceiveOnlyData() {
        testReceiveResult(testData, nil, nil,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(unknownError))])
    }

    func testReceiveDataAndResponse() {
        testReceiveResult(testData, testResponse, nil,
                          expected: [.subscription("DataTaskPublisher"),
                                     .value((testData, testResponse)),
                                     .completion(.finished)])
    }

    func testReceiveDataAndURLError() {
        testReceiveResult(testData, nil, testError,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(testError))])
    }

    func testReceiveDataAndUnrelatedError() {
        testReceiveResult(testData, nil, TestingError.oops,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(unknownError))])
    }

    func testReceiveOnlyResponse() {
        testReceiveResult(nil, testResponse, nil,
                          expected: [.subscription("DataTaskPublisher"),
                                     .value((Data(), testResponse)),
                                     .completion(.finished)])
    }

    func testReceiveResponseAndURLError() {
        testReceiveResult(nil, testResponse, testError,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(testError))])
    }

    func testReceiveResponseAndUnrelatedError() {
        testReceiveResult(nil, testResponse, TestingError.oops,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(unknownError))])
    }

    func testReceiveOnlyURLError() {
        testReceiveResult(nil, nil, testError,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(testError))])
    }

    func testReceiveOnlyUnrelatedError() {
        testReceiveResult(nil, nil, TestingError.oops,
                          expected: [.subscription("DataTaskPublisher"),
                                     .completion(.failure(unknownError))])
    }

    func testRequesting() throws {
        let dataTask = TestURLSessionDataTask()
        let session = TestURLSession(testDataTask: dataTask)
        let publisher = makePublisher(session, testRequest)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        publisher.subscribe(tracking)

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [])
        XCTAssertEqual(session.history, [])

        session.completeDataTasks(testData, testResponse, nil)

        try XCTUnwrap(downstreamSubscription).request(.max(2))
        try XCTUnwrap(downstreamSubscription).request(.max(1))

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [.resume, .resume])
        XCTAssertEqual(session.history, [.dataTaskWithRequestAndCompletion(testRequest)])

        try XCTUnwrap(downstreamSubscription).cancel()

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [.resume, .resume, .cancel])
        XCTAssertEqual(session.history, [.dataTaskWithRequestAndCompletion(testRequest)])

        session.completeDataTasks(testData, testResponse, nil)

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [.resume, .resume, .cancel])
        XCTAssertEqual(session.history, [.dataTaskWithRequestAndCompletion(testRequest)])
    }

    func testCancelAlreadyCancelled() throws {
        let dataTask = TestURLSessionDataTask()
        let session = TestURLSession(testDataTask: dataTask)
        let publisher = makePublisher(session, testRequest)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        publisher.subscribe(tracking)

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [])
        XCTAssertEqual(session.history, [])

        try XCTUnwrap(downstreamSubscription).request(.max(1))
        try XCTUnwrap(downstreamSubscription).cancel()
        try XCTUnwrap(downstreamSubscription).request(.max(1))
        try XCTUnwrap(downstreamSubscription).cancel()

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [.resume, .cancel])
        XCTAssertEqual(session.history, [.dataTaskWithRequestAndCompletion(testRequest)])
    }

    func testCrashesOnZeroDemand() throws {
        let dataTask = TestURLSessionDataTask()
        let session = TestURLSession(testDataTask: dataTask)
        let publisher = makePublisher(session, testURL)
        var downstreamSubscription: Subscription?
        let tracking = TrackingSubscriber(
            receiveSubscription: { downstreamSubscription = $0 }
        )
        publisher.subscribe(tracking)

        try assertCrashes {
            try XCTUnwrap(downstreamSubscription).request(.none)
        }
    }

    func testURLSessionSubscriptionReflection() throws {
        let dataTask = TestURLSessionDataTask()
        let session = TestURLSession(testDataTask: dataTask)
        let publisher = makePublisher(session, testURL)
        try testSubscriptionReflection(
            description: "DataTaskPublisher",
            customMirror: expectedChildren(
                ("task", "nil"),
                ("downstream", .contains("TrackingSubscriberBase")),
                ("parent", .matches(String(describing: Optional(publisher)))),
                ("demand", "max(0)")
            ),
            playgroundDescription: "DataTaskPublisher",
            sut: publisher
        )
    }

    // MARK: - Generic tests

    private func testReceiveResult(_ data: Data?,
                                   _ response: URLResponse?,
                                   _ error: Error?,
                                   expected: [TrackingSubscriber.Event]) {
        let dataTask = TestURLSessionDataTask()
        let session = TestURLSession(testDataTask: dataTask)
        let publisher = makePublisher(session, testRequest)
        let tracking = TrackingSubscriber(receiveSubscription: { $0.request(.max(1)) })
        publisher.subscribe(tracking)

        tracking.assertHistoryEqual([.subscription("DataTaskPublisher")],
                                    valueComparator: ==)
        XCTAssertEqual(dataTask.history, [.resume])
        XCTAssertEqual(session.history, [.dataTaskWithRequestAndCompletion(testRequest)])

        session.completeDataTasks(data, response, error)
        session.completeDataTasks(data, response, error)
        session.completeDataTasks(data, response, error)

        tracking.assertHistoryEqual(expected, valueComparator: ==)
        XCTAssertEqual(dataTask.history, [.resume])
        XCTAssertEqual(session.history, [.dataTaskWithRequestAndCompletion(testRequest)])
    }
}

/// A simple mock URLSession that records its history and allows executing
/// callbacks synchronously
private class TestURLSession: URLSession {

    enum Event: Equatable {
        case delegateQueue
        case delegate
        case configuration
        case getSessionDescription
        case setSessionDescription(String?)
        case finishTasksAndInvalidate
        case invalidateAndCancel
        case reset
        case flush
        case getTasksWithCompletionHandler
        case getAllTasks
        case dataTaskWithRequest(URLRequest)
        case dataTaskWithRequestAndCompletion(URLRequest)
        case dataTaskWithURL(URL)
        case dataTaskWithURLAndCompletion(URL)
        case uploadTaskWithRequestFromFile(URLRequest, URL)
        case uploadTaskWithRequestFromFileWithCompletion(URLRequest, URL)
        case uploadTaskWithRequestFromData(URLRequest, Data)
        case uploadTaskWithRequestFromDataWithCompletion(URLRequest, Data?)
        case uploadTaskWithStreamedRequest(URLRequest)
        case downloadTaskWithRequest(URLRequest)
        case downloadTaskWithRequestAndCompletion(URLRequest)
        case downloadTaskWithURL(URL)
        case downloadTaskWithURLAndCompletion(URL)
        case downloadTaskWithResumeData(Data)
        case downloadTaskWithResumeDataAndCompletion(Data)
        case streamTaskWithHostNameAndPort(String, Int)
#if canImport(Darwin) && swift(>=5.1)
        case streamTaskWithService(NetService)
        case webSocketTaskWithURL(URL)
        case webSocketTaskWithURLAndProtocols(URL, [String])
        case webSocketTaskWithRequest(URLRequest)
#endif // canImport(Darwin) && swift(>=5.1)
    }

    private(set) var history = [Event]()

    private(set) var dataTaskCompletionHandlers: [(Data?, URLResponse?, Error?) -> Void]

    private let testDataTask: TestURLSessionDataTask

    init(testDataTask: TestURLSessionDataTask) {
        self.testDataTask = testDataTask
        self.dataTaskCompletionHandlers = []
#if !canImport(Darwin)
        super.init(configuration: .default)
#endif
    }

    // MARK: Testing

    func completeDataTasks(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        for completionHandler in dataTaskCompletionHandlers {
            completionHandler(data, response, error)
        }
    }

    // MARK: Overrides

    override class var shared: URLSession { fatalError("shared session is unavailable") }

    override var delegateQueue: OperationQueue {
        history.append(.delegateQueue)
        return super.delegateQueue
    }

    override var delegate: URLSessionDelegate? {
        history.append(.delegate)
        return super.delegate
    }

    override var configuration: URLSessionConfiguration {
        history.append(.configuration)
        return super.configuration
    }

    override var sessionDescription: String? {
        get {
            history.append(.getSessionDescription)
            return super.sessionDescription
        }
        set {
            history.append(.setSessionDescription(newValue))
            super.sessionDescription = newValue
        }
    }

    override func finishTasksAndInvalidate() {
        history.append(.finishTasksAndInvalidate)
        super.finishTasksAndInvalidate()
    }

    override func invalidateAndCancel() {
        history.append(.invalidateAndCancel)
        super.invalidateAndCancel()
    }

    override func reset(completionHandler: @escaping () -> Void) {
        history.append(.reset)
        super.reset(completionHandler: completionHandler)
    }

    override func flush(completionHandler: @escaping () -> Void) {
        history.append(.flush)
        super.flush(completionHandler: completionHandler)
    }

    override func getTasksWithCompletionHandler(
        _ completionHandler: @escaping ([URLSessionDataTask],
                                        [URLSessionUploadTask],
                                        [URLSessionDownloadTask]) -> Void
    ) {
        history.append(.getTasksWithCompletionHandler)
        super.getTasksWithCompletionHandler(completionHandler)
    }

    @available(macOS 10.11, iOS 9.0, *)
    override func getAllTasks(completionHandler: @escaping ([URLSessionTask]) -> Void) {
        history.append(.getAllTasks)
        super.getAllTasks(completionHandler: completionHandler)
    }

    override func dataTask(with request: URLRequest) -> URLSessionDataTask {
        history.append(.dataTaskWithRequest(request))
        return testDataTask
    }

    override func dataTask(with url: URL) -> URLSessionDataTask {
        history.append(.dataTaskWithURL(url))
        return testDataTask
    }

    override func dataTask(
        with url: URL,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        history.append(.dataTaskWithURLAndCompletion(url))
        dataTaskCompletionHandlers.append(completionHandler)
        return testDataTask
    }

    override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        history.append(.dataTaskWithRequestAndCompletion(request))
        dataTaskCompletionHandlers.append(completionHandler)
        return testDataTask
    }

    override func uploadTask(with request: URLRequest,
                             fromFile fileURL: URL) -> URLSessionUploadTask {
        history.append(.uploadTaskWithRequestFromFile(request, fileURL))
        return super.uploadTask(with: request, fromFile: fileURL)
    }

    override func uploadTask(with request: URLRequest,
                             from bodyData: Data) -> URLSessionUploadTask {
        history.append(.uploadTaskWithRequestFromData(request, bodyData))
        return super.uploadTask(with: request, from: bodyData)
    }

    override func uploadTask(
        withStreamedRequest request: URLRequest
    ) -> URLSessionUploadTask {
        history.append(.uploadTaskWithStreamedRequest(request))
        return super.uploadTask(withStreamedRequest: request)
    }

    override func uploadTask(
        with request: URLRequest,
        fromFile fileURL: URL,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        history.append(.uploadTaskWithRequestFromFileWithCompletion(request, fileURL))
        return super.uploadTask(with: request,
                                fromFile: fileURL,
                                completionHandler: completionHandler)
    }

    override func uploadTask(
        with request: URLRequest,
        from bodyData: Data?,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionUploadTask {
        history.append(.uploadTaskWithRequestFromDataWithCompletion(request, bodyData))
        return super.uploadTask(with: request,
                                from: bodyData,
                                completionHandler: completionHandler)
    }

    override func downloadTask(with request: URLRequest) -> URLSessionDownloadTask {
        history.append(.downloadTaskWithRequest(request))
        return super.downloadTask(with: request)
    }

    override func downloadTask(with url: URL) -> URLSessionDownloadTask {
        history.append(.downloadTaskWithURL(url))
        return super.downloadTask(with: url)
    }

    override func downloadTask(
        with request: URLRequest,
        completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        history.append(.downloadTaskWithRequestAndCompletion(request))
        return super.downloadTask(with: request, completionHandler: completionHandler)
    }

    override func downloadTask(
        with url: URL,
        completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        history.append(.downloadTaskWithURLAndCompletion(url))
        return super.downloadTask(with: url, completionHandler: completionHandler)
    }

    override func downloadTask(
        withResumeData resumeData: Data,
        completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        history.append(.downloadTaskWithResumeDataAndCompletion(resumeData))
        return super.downloadTask(withResumeData: resumeData,
                                  completionHandler: completionHandler)
    }

    override func downloadTask(
        withResumeData resumeData: Data
    ) -> URLSessionDownloadTask {
        history.append(.downloadTaskWithResumeData(resumeData))
        return super.downloadTask(withResumeData: resumeData)
    }

#if canImport(Darwin)
    @available(macOS 10.11, iOS 9.0, *)
    override func streamTask(withHostName hostname: String,
                             port: Int) -> URLSessionStreamTask {
        history.append(.streamTaskWithHostNameAndPort(hostname, port))
        return super.streamTask(withHostName: hostname, port: port)
    }

#if swift(>=5.1)
    @available(macOS 10.11, iOS 9.0, *)
    override func streamTask(with service: NetService) -> URLSessionStreamTask {
        history.append(.streamTaskWithService(service))
        return super.streamTask(with: service)
    }

    @available(macOS 10.15, iOS 13.0, *)
    override func webSocketTask(with url: URL) -> URLSessionWebSocketTask {
        history.append(.webSocketTaskWithURL(url))
        return super.webSocketTask(with: url)
    }

    @available(macOS 10.15, iOS 13.0, *)
    override func webSocketTask(with url: URL,
                                protocols: [String]) -> URLSessionWebSocketTask {
        history.append(.webSocketTaskWithURLAndProtocols(url, protocols))
        return super.webSocketTask(with: url, protocols: protocols)
    }

    @available(macOS 10.15, iOS 13.0, *)
    override func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask {
        history.append(.webSocketTaskWithRequest(request))
        return super.webSocketTask(with: request)
    }
#endif // swift(>=5.1)
#endif // canImport(Darwin)
}

private final class TestURLSessionDataTask: URLSessionDataTask {

    enum Event: Equatable {
        case taskIdentifier
        case originalRequest
        case currentRequest
        case response
        case progress
        case getEarliestBeginDate
        case setEarliestBeginDate(Date?)
        case getCountOfBytesClientExpectsToSend
        case setCountOfBytesClientExpectsToSend(Int64)
        case getCountOfBytesClientExpectsToReceive
        case setCountOfBytesClientExpectsToReceive(Int64)
        case countOfBytesReceived
        case countOfBytesSent
        case countOfBytesExpectedToSend
        case countOfBytesExpectedToReceive
        case getTaskDescription
        case setTaskDescription(String?)
        case cancel
        case state
        case error
        case suspend
        case resume
        case getPriority
        case setPriority(Float)
    }

    private(set) var history = [Event]()

    override init() {}

    override var taskIdentifier: Int {
        history.append(.taskIdentifier)
        return super.taskIdentifier
    }

    override var originalRequest: URLRequest? {
        history.append(.originalRequest)
        return super.originalRequest
    }

    override var currentRequest: URLRequest? {
        history.append(.currentRequest)
        return super.currentRequest
    }

    override var response: URLResponse? {
        history.append(.response)
        return super.response
    }

    @available(macOS 10.13, iOS 11.0, *)
    override var progress: Progress {
        history.append(.progress)
        return super.progress
    }

    @available(macOS 10.13, iOS 11.0, *)
    override var earliestBeginDate: Date? {
        get {
            history.append(.getEarliestBeginDate)
#if canImport(Darwin)
            return super.earliestBeginDate
#else
            return nil // Deprecated in swift-corelibs-foundation
#endif
        }
        set {
            history.append(.setEarliestBeginDate(newValue))
#if canImport(Darwin)
            super.earliestBeginDate = newValue
#endif
        }
    }

    @available(macOS 10.13, iOS 11.0, *)
    override var countOfBytesClientExpectsToSend: Int64 {
        get {
            history.append(.getCountOfBytesClientExpectsToSend)
            return super.countOfBytesClientExpectsToSend
        }
        set {
            history.append(.setCountOfBytesClientExpectsToSend(newValue))
            super.countOfBytesClientExpectsToSend = newValue
        }
    }

    @available(macOS 10.13, iOS 11.0, *)
    override var countOfBytesClientExpectsToReceive: Int64 {
        get {
            history.append(.getCountOfBytesClientExpectsToReceive)
            return super.countOfBytesClientExpectsToReceive
        }
        set {
            history.append(.setCountOfBytesClientExpectsToReceive(newValue))
            super.countOfBytesClientExpectsToReceive = newValue
        }
    }

    override var countOfBytesReceived: Int64 {
        history.append(.countOfBytesReceived)
        return super.countOfBytesReceived
    }

    override var countOfBytesSent: Int64 {
        history.append(.countOfBytesSent)
        return super.countOfBytesSent
    }

    override var countOfBytesExpectedToSend: Int64 {
        history.append(.countOfBytesExpectedToSend)
        return super.countOfBytesExpectedToSend
    }

    override var countOfBytesExpectedToReceive: Int64 {
        history.append(.countOfBytesExpectedToReceive)
        return super.countOfBytesExpectedToReceive
    }

    override var taskDescription: String? {
        get {
            history.append(.getTaskDescription)
            return super.taskDescription
        }
        set {
            history.append(.setTaskDescription(newValue))
            super.taskDescription = newValue
        }
    }

    override func cancel() {
        history.append(.cancel)
    }

    override var state: URLSessionTask.State {
        history.append(.state)
        return super.state
    }

    override var error: Error? {
        history.append(.error)
        return super.error
    }

    override func suspend() {
        history.append(.suspend)
    }

    override func resume() {
        history.append(.resume)
    }

    override var priority: Float {
        get {
            history.append(.getPriority)
            return super.priority
        }
        set {
            history.append(.setPriority(newValue))
            super.priority = newValue
        }
    }
}

extension URLError: EquatableError {}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
@available(macOS 10.15, iOS 13.0, *)
private func makePublisher(
    _ session: URLSession,
    _ url: URL
) -> URLSession.DataTaskPublisher {
    return session.dataTaskPublisher(for: url)
}

@available(macOS 10.15, iOS 13.0, *)
private func makePublisher(
    _ session: URLSession,
    _ request: URLRequest
) -> URLSession.DataTaskPublisher {
    return session.dataTaskPublisher(for: request)
}
#else
private func makePublisher(
    _ session: URLSession,
    _ url: URL
) -> URLSession.OCombine.DataTaskPublisher {
    return session.ocombine.dataTaskPublisher(for: url)
}

private func makePublisher(
    _ session: URLSession,
    _ request: URLRequest
) -> URLSession.OCombine.DataTaskPublisher {
    return session.ocombine.dataTaskPublisher(for: request)
}
#endif // OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)

#endif // canImport(Darwin)

#endif // !WASI
