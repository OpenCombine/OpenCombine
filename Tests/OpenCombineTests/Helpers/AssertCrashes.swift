//
//  AssertCrashes.swift
//  
//
//  Created by Sergej Jaskiewicz on 31.07.2019.
//

import XCTest
import Foundation

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
    @available(macOS 10.13, *)
    func assertCrashes(within block: () throws -> Void) rethrows {
#if !Xcode
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

            let childProcess = Process()
            childProcess.executableURL = xctestUtilityPath
            arguments[0] = "\(testcaseName)/\(testName)"
            childProcess.arguments = arguments
            print(arguments)

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
