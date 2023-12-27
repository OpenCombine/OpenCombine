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
	OPENCOMBINE_COMPATIBILITY_TEST=1 $(SWIFT_EXE) test

library-evolution:
	OPENCOMBINE_LIBRARY_EVOLUTION=1 $(SWIFT_EXE) build

module-interface:
	xcodebuild build -scheme OpenCombine -sdk macosx -destination "platform=macOS" BUILD_LIBRARY_FOR_DISTRIBUTION=1

gyb:
	$(shell ./utils/recursively_gyb.sh)

clean:
	rm -rf .build

.PHONY: debug release \
	    test-debug \
	    test-release \
	    swift-version \
	    test-compatibility-debug \
		library-evolution \
		module-interface \
	    gyb \
	    clean
