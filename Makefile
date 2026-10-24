.PHONY: dev

dev:
	(killall Xcode || true)

	# Create the generated mocks files, which the build populates later.
	touch "Tests/Swift/Generated/GeneratedMocks.swift" "Tests/Swift/Generated/GeneratedMocks+SwiftUI.swift"

	mise install

	# Resolve the dependencies Tuist reads from Package.swift, so generate doesn't report them as outdated.
	TUIST_PROJECT_DIR=$(PWD) mise exec -- tuist install

	# Generate Xcode structure.
	TUIST_PROJECT_DIR=$(PWD) mise exec -- tuist generate --no-open

	xed Cuckoo.xcworkspace
