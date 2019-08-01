import Danger

let danger = Danger()

SwiftLint.lint(inline: true,
               configFile: ".swiftlint.yml",
               strict: true,
               lintAllFiles: true)

if danger.warnings.isEmpty, danger.fails.isEmpty {
    markdown("LGTM")
}
