import XCTest
@testable import OpenCombine

final class OpenCombineTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(OpenCombine().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
