//
//  TestCase.swift
//  
//
//  Created by Sergej Jaskiewicz on 29.11.2019.
//

import XCTest

class TestCase: XCTestCase {

    var hasFailed = false

    override func recordFailure(withDescription description: String,
                                inFile filePath: String,
                                atLine lineNumber: Int,
                                expected: Bool) {
        hasFailed = true
        super.recordFailure(withDescription: description,
                            inFile: filePath,
                            atLine: lineNumber,
                            expected: expected)
    }

    override func setUp() {
        super.setUp()
        hasFailed = false
    }
}
