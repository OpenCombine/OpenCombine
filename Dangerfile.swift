import Danger
import Foundation

extension StringProtocol {
    func dropSuffix<S: StringProtocol>(_ suffix: S) -> SubSequence {
        if hasSuffix(suffix) {
            return self[..<index(endIndex, offsetBy: -suffix.count)]
        } else {
            return self[...]
        }
    }

    func directoryAndFileName() -> (SubSequence, SubSequence) {
        let lastPathSeparator = lastIndex(of: "/")
        if let lastPathSeparator = lastPathSeparator {
            return (self[..<lastPathSeparator], self[index(after: lastPathSeparator)...])
        } else {
            return (".", self[...])
        }
    }
}

let danger = Danger()

let allCreatedAndModified = danger.git.createdFiles + danger.git.modifiedFiles

do {
    // Fail if the committer modified a GYB template but forgot to run `make gyb`.

    let modifiedTemplates = allCreatedAndModified.filter { $0.hasSuffix(".gyb") }

    for modifiedTemplate in modifiedTemplates {
        let (directory, filename) = modifiedTemplate.directoryAndFileName()
        let generated = "\(directory)/GENERATED-\(filename.dropSuffix(".gyb"))"

        if !allCreatedAndModified.contains(generated) {
            fail("""
            A template \(modifiedTemplate) was modified, but the file \(generated) \
            was not regenerated.

            Run `make gyb` from the root of the project and commit the changes.
            """)
        }
    }
}

do {
    // Fail if the committer modified a generated file.
    // A template should be modified instead.

    for modifiedGeneratedFile in danger.git.modifiedFiles
        where modifiedGeneratedFile.contains("GENERATED-")
    {
        let template = modifiedGeneratedFile
            .replacingOccurrences(of: "GENERATED-", with: "") + ".gyb"

        if !danger.git.modifiedFiles.contains(template) {
            fail("""
            A generated file \(modifiedGeneratedFile) was modified, but \
            the template it was generated from was not modified.

            Please modify the template \(template) instead, \
            run `make gyb` from the root of the project and commit the changes.
            """)
        }
    }
}

SwiftLint.lint(inline: true,
               configFile: ".swiftlint.yml",
               strict: true,
               lintAllFiles: true)

if danger.warnings.isEmpty, danger.fails.isEmpty {
    markdown("LGTM")
}
