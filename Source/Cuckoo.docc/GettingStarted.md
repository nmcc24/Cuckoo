# Getting started

Add Cuckoo to a test target, generate mocks with a build plugin, and write a first test.

## Overview

Cuckoo has two parts: the `Cuckoo` library that tests link against, and a generator that reads your sources and
writes a mock for each protocol and class. A SwiftPM or Xcode build plugin runs the generator on every build, so
the mocks always match the code.

### Requirements

- Swift 6.2 or later (Xcode 26 or later). The Swift 6 language mode is recommended; the mocks also compile in
  the Swift 5 mode, which CI doesn't test.
- iOS 17, macOS 14, tvOS 17 or watchOS 10, or Linux.

### Add the package

Add Cuckoo to the test targets only; the mocks and the library don't belong in an app.

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Brightify/Cuckoo.git", from: "3.0.0"),
],
targets: [
    .testTarget(
        name: "AppTests",
        dependencies: ["App", .product(name: "Cuckoo", package: "Cuckoo")],
        plugins: [.plugin(name: "CuckooPlugin", package: "Cuckoo")]
    ),
]
```

> Note: The 3.0 betas are published on the fork, `https://github.com/nmcc24/Cuckoo.git`. A version requirement
> such as `from: "3.0.0"` never picks a pre-release, so name the beta exactly: `exact: "3.0.0-beta.1"`.

In an Xcode project, add the package with File > Add Package Dependencies, link the `Cuckoo` library to the test
target, and add the plugin under the test target's Build Phases > Run Build Tool Plug-ins. Xcode asks you to trust
the plugin the first time it runs; on CI, pass `-skipPackagePluginValidation` to `xcodebuild`.

### How the plugin generates

`CuckooPlugin` generates one file of mocks per module the test target depends on, from the Cuckoofile entry with
that module's name, plus one from the entry named after the test target itself. Each file is its own build step, so
a change in one module regenerates and recompiles only that module's mocks, and the steps run in parallel.

A release's plugin runs a prebuilt generator, on macOS and on Linux (x86_64 and arm64), so your build doesn't compile
swift-syntax and its version doesn't constrain your other packages. A dependency on a branch or a commit instead
builds the generator from source with the plugin.

### Write a Cuckoofile

The plugin reads `Cuckoofile.toml` at the root of the package or project. The smallest one names the module whose
types you want mocked:

```toml
[modules.App]
testableImports = ["App"]
```

With no `sources`, the entry mocks every file of the test target's dependency named `App`. See <doc:Cuckoofile>
for every key.

### Write a test

Each mocked type `Greeter` gets a mock `MockGreeter`, with the same initializers, and a stub `GreeterStub` that
returns default values:

```swift
import Cuckoo
import Testing
@testable import App

@Test(.cuckoo())
func welcomesTheUser() {
    let greeter = MockGreeter()
    stub(greeter) { stub in
        when(stub.greet(name: any())).thenReturn("Hello")
    }

    let screen = WelcomeScreen(greeter: greeter)

    #expect(screen.title == "Hello")
    verify(greeter).greet(name: "Ann")
}
```

The `.cuckoo()` trait is optional for instance members: it gives the test its own configuration and its own
registry for static members' stubs. In XCTest, wrap code that uses static members in `withStaticStubs { }`.

A call that no stub matches fails the test, then returns a default value so the test can go on. See
<doc:StubbingAndVerification> for stubbing, spies, default implementations and verification, and <doc:Matching>
for matching arguments.
