# Getting started

Add Cuckoo to a test target, generate mocks with a build plugin, and write a first test.

## Overview

Cuckoo has two parts: the `Cuckoo` library that tests link against, and a generator that reads your sources and
writes a mock for each protocol and class. A SwiftPM or Xcode build plugin runs the generator on every build, so
the mocks always match the code.

### Requirements

- Swift 6.2 or later (Xcode 26 or later), in the Swift 6 language mode.
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
        plugins: [.plugin(name: "CuckooPluginModular", package: "Cuckoo")]
    ),
]
```

In an Xcode project, add the package with File > Add Package Dependencies, link the `Cuckoo` library to the test
target, and add the plugin under the test target's Build Phases > Run Build Tool Plug-ins. Xcode asks you to trust
the plugin the first time it runs; on CI, pass `-skipPackagePluginValidation` to `xcodebuild`.

### Choose a plugin

- term `CuckooPluginModular`: Generates one file of mocks per module the test target depends on, from the
  Cuckoofile entry with that module's name, plus one from the entry named after the test target itself. Use it in
  packages and in projects with several modules.
- term `CuckooPluginSingleFile`: Generates every Cuckoofile module into a single file. Use it when one test target
  mocks types from one place, or when mocks of several modules must share a file.

The generator builds from source with the plugin, so the first build compiles swift-syntax.

### Write a Cuckoofile

The plugins read `Cuckoofile.toml` at the root of the package or project. The smallest one names the module whose
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
