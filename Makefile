.PHONY: dev

dev:
	(killall Xcode || true)

	# Create the generated mocks files, which the build populates later.
	touch "Tests/Swift/Generated/GeneratedMocks.swift" "Tests/Swift/Generated/GeneratedMocks+SwiftUI.swift"

	mise install

	# Generate Xcode structure.
	TUIST_PROJECT_DIR=$(PWD) tuist generate --no-open

	xed Cuckoo.xcworkspace
