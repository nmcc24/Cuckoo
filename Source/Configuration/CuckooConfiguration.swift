#if canImport(Testing)
import Testing
#endif
#if canImport(XCTest)
import XCTest
#endif

/// Settings for the mocks used in the current task. Set them for a Swift Testing test or suite with the
/// `.cuckoo(…)` trait, or for any scope with `CuckooConfiguration.$current.withValue(…)`.
///
/// A call with no matching stub always records a failure, then answers so the test can go on: a member that
/// throws `any Error` throws `CuckooError.unstubbedCall`, and any other member returns its type's default value. A
/// `rethrows` member returns the default value too: its caller may have passed closures that don't throw, and then
/// has no `try` to catch an error with.
/// It crashes only when neither is possible.
public struct CuckooConfiguration: Sendable {
    /// Receives each failure instead of the test framework. `nil` reports to the framework running the test.
    public typealias FailureHandler = @Sendable (_ message: String, _ sourceLocation: SourceLocation) -> Void

    /// Default values that take precedence over `DefaultValueRegistry` for this scope.
    public var defaultValues: DefaultValues
    /// Receives each failure instead of the test framework, `nil` by default.
    public var failureHandler: FailureHandler?
    /// Takes each failure before ``failureHandler``, with its location if it has one: `eventually` holds failures
    /// back with it and reports them later.
    var failureCollector: (@Sendable (_ message: String, _ sourceLocation: SourceLocation?) -> Void)?

    /// Creates a configuration with `defaultValues` and `failureHandler`.
    public init(defaultValues: DefaultValues = DefaultValues(), failureHandler: FailureHandler? = nil) {
        self.defaultValues = defaultValues
        self.failureHandler = failureHandler
    }

    /// The configuration for the current task.
    @TaskLocal public static var current = CuckooConfiguration()
}

/// Default values for unstubbed calls, keyed by type.
public struct DefaultValues: Sendable {
    private var values: [ObjectIdentifier: DefaultValueFactory] = [:]

    /// Creates an empty set of default values.
    public init() {
    }

    /// Registers `value` as the default for `type` in this set.
    public mutating func register<T: Sendable>(_ value: T, for type: T.Type = T.self) {
        values[ObjectIdentifier(type)] = DefaultValueFactory(value)
    }

    /// Registers `factory` to make the default for `type` in this set. Each unstubbed call gets a new value, so
    /// `type` needn't be `Sendable`: a class, or a tuple such as `(Int, String)`.
    public mutating func register<T>(for type: T.Type = T.self, factory: @escaping @Sendable () -> T) {
        values[ObjectIdentifier(type)] = DefaultValueFactory(factory)
    }

    func value<T>(for type: T.Type) -> T? {
        values[ObjectIdentifier(type)]?.make(type)
    }
}

/// Errors a mock throws on its own.
public enum CuckooError: Error, Sendable, Equatable {
    /// A throwing member was called with no matching stub.
    case unstubbedCall(method: String)
}

/// The Swift Testing test a mock was created in, so a failure from a task the test doesn't run in can still go to
/// Swift Testing, at that test.
struct CreatingTest: Sendable {
    #if canImport(Testing)
    let sourceLocation: Testing.SourceLocation
    #endif

    /// The test the current task runs, if it's a Swift Testing test.
    static var current: CreatingTest? {
        #if canImport(Testing)
        Test.current.map { CreatingTest(sourceLocation: $0.sourceLocation) }
        #else
        nil
        #endif
    }
}

/// Reports a failure to the current configuration's handler, or else to the framework running the current test
/// only. Swift Testing flags an `XCTFail` inside its tests, and XCTest doesn't see Swift Testing issues.
///
/// A failure with no `sourceLocation`, such as an unstubbed call, which happens inside the mock, is reported at the
/// Swift Testing test. Elsewhere it has no better place than this function.
///
/// `creatingTest` is the Swift Testing test the mock was created in. A task the test doesn't run in, such as a
/// `Task.detached` or a dispatch queue, has no current test, so its failure would go to XCTest, which ignores it;
/// such a failure is recorded as a Swift Testing issue instead. Swift Testing can't tell which test it belongs to,
/// so it fails the run under no test, at the failure's location or else at the test that created the mock.
func reportFailure(_ message: String, at sourceLocation: SourceLocation?, creatingTest: CreatingTest? = nil) {
    let configuration = CuckooConfiguration.current
    if let collector = configuration.failureCollector {
        collector(message, sourceLocation)
        return
    }
    if let handler = configuration.failureHandler {
        handler(message, sourceLocation ?? (#fileID, #filePath, #line, #column))
        return
    }
    #if canImport(Testing)
    if let location = swiftTestingIssueLocation(for: sourceLocation, creatingTest: creatingTest) {
        Issue.record(Comment(rawValue: message), sourceLocation: location)
        return
    }
    #endif
    #if canImport(XCTest)
    if let sourceLocation {
        XCTFail(message, file: sourceLocation.filePath, line: UInt(sourceLocation.line))
    } else {
        XCTFail(message)
    }
    #else
    print("Cuckoo failure:", message, sourceLocation ?? (#fileID, #filePath, #line, #column))
    #endif
}

#if canImport(Testing)
/// Where a failure goes in Swift Testing, or `nil` when Swift Testing isn't involved and it goes to XCTest: the
/// failure's own location, else the current test, else the test that created the mock.
func swiftTestingIssueLocation(for sourceLocation: SourceLocation?, creatingTest: CreatingTest?) -> Testing.SourceLocation? {
    guard let test = Test.current.map({ CreatingTest(sourceLocation: $0.sourceLocation) }) ?? creatingTest else {
        return nil
    }
    return sourceLocation.map(testingSourceLocation) ?? test.sourceLocation
}

private func testingSourceLocation(_ sourceLocation: SourceLocation) -> Testing.SourceLocation {
    Testing.SourceLocation(
        fileID: sourceLocation.fileID,
        filePath: "\(sourceLocation.filePath)",
        line: sourceLocation.line,
        column: sourceLocation.column
    )
}
#endif
