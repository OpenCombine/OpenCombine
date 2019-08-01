debug:
	swift build -c debug

release:
	swift build -c release

test-debug:
	swift test -c debug --enable-code-coverage --sanitize thread

test-release:
	swift test -c release

swift-version:
	swift -version

test-compatibility:
	swift test -Xswiftc -DOPENCOMBINE_COMPATIBILITY_TEST

generate-compatibility-xcodeproj:
	swift package generate-xcodeproj --xcconfig-overrides Combine-Compatibility.xcconfig; \
	open OpenCombine.xcodeproj

generate-xcodeproj:
	swift package generate-xcodeproj --enable-code-coverage

.PHONY: debug release test-debug test-release swift-version test-compatibility-debug generate-compatibility-xcodeproj generate-xcodeproj
