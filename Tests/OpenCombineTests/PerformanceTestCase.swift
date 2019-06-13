//
//  File.swift
//  
//
//  Created by Sergej Jaskiewicz on 13.06.2019.
//

import GottaGoFast
import XCTest

class PerformanceTestCase: GottaGoFast.PerformanceTestCase {
#if OPENCOMBINE_COMPATIBILITY_TEST
    override var testInfo: String {
        "OPENCOMBINE_COMPATIBILITY_TEST"
    }
#endif
}

extension XCTestCase {

    var isDebug: Bool {
#if DEBUG
        return true
#else
        return false
#endif
    }
}
