//
//  AssertCrashes.swift
//  
//
//  Created by Sergej Jaskiewicz on 31.07.2019.
//

import Foundation
import XCTest

extension XCTest {

    var testcaseName: String {
        return String(describing: type(of: self))
    }

    var testName: String {
        // Since on Apple platforms `self.name` has
        // format `-[XCTestCaseSubclassName testMethodName]`,
        // and on other platforms the format is
        // `XCTestCaseSubclassName.testMethodName`
        // we have this workaround in order to unify the names
        return name
            .components(separatedBy: testcaseName)
            .last!
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    // Taken from swift-corelibs-foundation and slightly modified for OpenCombine
    @available(macOS 10.13, iOS 8.0, *)
    func assertCrashes(within block: () throws -> Void) rethrows {
#if !Xcode && !os(iOS) && !os(watchOS) && !os(tvOS)
        let childProcessEnvVariable = "OPENCOMBINE_TEST_PERFORM_ASSERT_CRASHES_BLOCKS"
        let childProcessEnvVariableOnValue = "YES"

        let isChildProcess = ProcessInfo
            .processInfo
            .environment[childProcessEnvVariable] == childProcessEnvVariableOnValue

        if isChildProcess {
            try block()
        } else {
            var arguments = ProcessInfo.processInfo.arguments
            let xctestUtilityPath = URL(fileURLWithPath: arguments[0])

            print("Parent process args:", arguments)

            let childProcess = Process()
            childProcess.executableURL = xctestUtilityPath

            arguments.removeFirst()
            arguments.removeAll { $0.hasPrefix("OpenCombineTests.") || $0 == "-XCTest" }
            arguments.insert("-XCTest", at: 0)
            arguments.insert("OpenCombineTests.\(testcaseName)/\(testName)", at: 1)
            childProcess.arguments = arguments

            print("Child process args:", arguments)

            var environment = ProcessInfo.processInfo.environment
            environment[childProcessEnvVariable] = childProcessEnvVariableOnValue
            childProcess.environment = environment

            do {
                try childProcess.run()
                childProcess.waitUntilExit()
                XCTAssert(childProcess.terminationReason == .uncaughtSignal,
                          "Child process should have crashed: \(childProcess)")
            } catch {
                XCTFail("""
                Couldn't start child process for testing crash: \(childProcess) - \(error)
                """)
            }
        }
#endif
    }
}
