# Cuckoo
## Mock your Swift objects!

[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-orange?style=flat)](https://swift.org)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-ready-brightgreen?style=flat)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat)](LICENSE)

Cuckoo generates mocks of your Swift protocols and classes at build time, and gives tests a
[Mockito](http://mockito.org/)-style API to stub them and verify their calls:

```swift
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

## How it works
Cuckoo has two parts: the `Cuckoo` library that tests link against, and a generator that reads your sources and
writes a mock for each protocol and class. A SwiftPM or Xcode build plugin runs the generator on every build, so the
mocks always match the code.

Mocks work by protocol conformance and subclassing, so only what can be overridden can be mocked: protocols, and
the non-`final` members of classes. Structs, `final` and `private` declarations, and global functions can't be;
put a protocol in front of them.

## Features
- Swift 6 concurrency: a mock keeps the isolation of the type it mocks. `@MainActor` and global-actor protocols get
  isolated mocks, `actor` protocols get actor mocks, and `Sendable` types get checked `Sendable` mocks.
- Swift Testing and XCTest, with a `.cuckoo()` trait for per-test configuration.
- Async and throwing members, typed throws, `inout`, `~Copyable` arguments and parameter packs.
- Generics, associated types, inheritance, static and class members, and subscripts.
- Spies, default implementations, argument captors, in-order verification and `eventually` for asynchronous code.
- Failure messages that show each call a member received and the argument that didn't match.

## Requirements
- Swift 6.2 or later (Xcode 26 or later), in the Swift 6 language mode.
- iOS 17, macOS 14, tvOS 17 or watchOS 10, or Linux.

## Documentation
The documentation is a DocC catalog in [`Source/Cuckoo.docc`](Source/Cuckoo.docc). Build it with
`scripts/build-docs.sh`, or open the package in Xcode and choose Product > Build Documentation.

- [Getting started](Source/Cuckoo.docc/GettingStarted.md): add the package and a build plugin, and write a first test.
- [The Cuckoofile](Source/Cuckoo.docc/Cuckoofile.md): every option of `Cuckoofile.toml`.
- [Stubbing and verification](Source/Cuckoo.docc/StubbingAndVerification.md): stubs, spies, default
  implementations, static members, verification, argument captors.
- [Matching arguments and calls](Source/Cuckoo.docc/Matching.md): matchers for arguments, collections and call
  counts.

- [Cookbook](Source/Cuckoo.docc/Cookbook.md): MainActor view models, background work, actors, Swift Testing suites,
  slow calls, Objective-C dependencies and completion handlers.
- [Migrating from Cuckoo 2](Source/Cuckoo.docc/MigratingFromCuckoo2.md): what changes for an existing suite.

The list of changes is in the [changelog](CHANGELOG.md).

## Contribute
Cuckoo is open for everyone and we'd like you to help us make the best Swift mocking library. For Cuckoo development, follow these steps:
1. Clone the **Cuckoo** repository.
2. Open `Package.swift` in Xcode, or run `swift test` (on macOS or Linux). It runs the generator's unit and snapshot tests and the runtime tests, with mocks the plugins generate from `Cuckoofile.toml`.
3. To test on a simulator, use the shared `CuckooTests` scheme with `xcodebuild -skipPackagePluginValidation`.
4. Peek around or file a pull request with your changes.

The package consists of two parts - runtime and code generator:
- `Source` - runtime sources and the DocC catalog
- `Generator` - the generator (`CuckooGenerator`), its build plugins and its tests
- `Tests` - tests for the runtime part, in Swift 6 mode like everything else

Thank you for your help!

## Inspiration
- [Mockito](http://mockito.org/) - Mocking DSL
- [Hamcrest](http://hamcrest.org/) - Matcher API

## Used libraries
- [ArgumentParser](https://github.com/apple/swift-argument-parser)
- [SwiftSyntax](https://github.com/apple/swift-syntax)
- [TOMLDecoder](https://github.com/dduan/TOMLDecoder)

## License
Cuckoo is available under the [MIT License](LICENSE).
