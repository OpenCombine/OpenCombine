SWIFT_TEST_FLAGS=

debug:
	swift build -c debug

release:
	swift build -c release

test-debug:
	swift test --parallel -c debug $(SWIFT_TEST_FLAGS)

test-debug-sanitize-thread:
	swift test --parallel -c debug --sanitize thread $(SWIFT_TEST_FLAGS)

test-release:
	swift test --parallel -c release $(SWIFT_TEST_FLAGS)

swift-version:
	swift -version

test-compatibility:
	swift test --parallel -Xswiftc -DOPENCOMBINE_COMPATIBILITY_TEST

generate-compatibility-xcodeproj:
	swift package generate-xcodeproj --xcconfig-overrides Combine-Compatibility.xcconfig; \
	open OpenCombine.xcodeproj

generate-xcodeproj:
	swift package generate-xcodeproj --enable-code-coverage

gyb:
	$(shell ./utils/recursively_gyb.sh)

clean:
	rm -rf .build

.PHONY: debug release \
	    test-debug \
	    test-release \
	    swift-version \
	    test-compatibility-debug \
	    generate-compatibility-xcodeproj \
	    generate-xcodeproj \
	    gyb \
	    clean
