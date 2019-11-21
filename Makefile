SWIFT_EXE=swift
SWIFT_TEST_FLAGS=
SWIFT_BUILD_FLAGS=-Xcc -Wunguarded-availability

debug:
	$(SWIFT_EXE) build -c debug $(SWIFT_BUILD_FLAGS)

release:
	$(SWIFT_EXE) build -c release $(SWIFT_BUILD_FLAGS)

test-debug:
	$(SWIFT_EXE) test -c debug $(SWIFT_BUILD_FLAGS) $(SWIFT_TEST_FLAGS)

test-debug-sanitize-thread:
	$(SWIFT_EXE) test -c debug --sanitize thread $(SWIFT_BUILD_FLAGS) $(SWIFT_TEST_FLAGS)

test-release:
	$(SWIFT_EXE) test -c release $(SWIFT_BUILD_FLAGS) $(SWIFT_TEST_FLAGS)

swift-version:
	$(SWIFT_EXE) -version

test-compatibility:
	$(SWIFT_EXE) test -Xswiftc -DOPENCOMBINE_COMPATIBILITY_TEST

generate-compatibility-xcodeproj:
	$(SWIFT_EXE) package generate-xcodeproj --xcconfig-overrides Combine-Compatibility.xcconfig; \
	open OpenCombine.xcodeproj

generate-xcodeproj:
	$(SWIFT_EXE) package $(SWIFT_BUILD_FLAGS) generate-xcodeproj --enable-code-coverage

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
