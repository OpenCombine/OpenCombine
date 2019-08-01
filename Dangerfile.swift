import Danger

let danger = Danger()

do {
    let addedTestFiles = danger
        .git
        .createdFiles
        .filter { $0.hasSuffix("Tests.swift") }

    let modifiedXCTestManifests = danger
        .git
        .modifiedFiles
        .contains { $0.hasSuffix("XCTestManifests.swift") }

    if !addedTestFiles.isEmpty && !modifiedXCTestManifests {

        let addedTestsClasses = addedTestFiles.map {
            "- " + $0.split(separator: "/").last!.dropLast(6)
        }.joined(separator: "\n")

        fail("""
        You've added the following test classes:

        \(addedTestsClasses)

        but forgot to modify `XCTestManifests.swift`.
        """)
    }
}

SwiftLint.lint(inline: true,
               configFile: ".swiftlint.yml",
               strict: true,
               lintAllFiles: true)

if danger.warnings.isEmpty, danger.fails.isEmpty {
    markdown("LGTM")
}
