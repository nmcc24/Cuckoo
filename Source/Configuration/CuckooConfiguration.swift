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
    /// Default values that take precedence over `DefaultValueRegistry` for this scope. A mock also keeps the values
    /// of the scope it was created in, for the types this scope doesn't register.
    public var defaultValues: DefaultValues
    /// Takes each failure instead of the test framework, with its location if it has one and the test that
    /// created the mock: `eventually` holds failures back with it and reports them later, and Cuckoo's own tests
    /// check them with it. `nil` reports to the framework running the test.
    var failureHandler: (@Sendable (_ failure: ReportedFailure) -> Void)?

    /// Creates a configuration with `defaultValues`.
    public init(defaultValues: DefaultValues = DefaultValues()) {
        self.defaultValues = defaultValues
    }

    /// Creates a configuration whose failures go to `failureHandler` instead of the test framework.
    init(defaultValues: DefaultValues = DefaultValues(), failureHandler: @escaping @Sendable (_ failure: ReportedFailure) -> Void) {
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
    /// `type` needn't be `Sendable`: a class, or a tuple that holds one, such as `(Int, Canvas)`.
    public mutating func register<T>(for type: T.Type = T.self, factory: @escaping @Sendable () -> T) {
        values[ObjectIdentifier(type)] = DefaultValueFactory(factory)
    }

    var isEmpty: Bool {
        values.isEmpty
    }

    func value<T>(for type: T.Type) -> T? {
        values[ObjectIdentifier(type)]?.make(type)
    }

    /// These values, with `fallback`'s for the types these don't have.
    func withFallback(_ fallback: DefaultValues) -> DefaultValues {
        var merged = self
        merged.values.merge(fallback.values) { own, _ in own }
        return merged
    }
}

/// Errors a mock throws on its own.
public enum CuckooError: Error, Sendable, Equatable {
    /// A throwing member was called with no matching stub.
    case unstubbedCall(method: String)
}

/// A failure as `reportFailure` receives it, which a configuration's `failureHandler` takes.
struct ReportedFailure: Sendable {
    let message: String
    let sourceLocation: SourceLocation?
    let creatingTest: CreatingTest?
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
/// such a failure is recorded as a Swift Testing issue instead, at the failure's location or else at the test that
/// created the mock. Swift Testing ties that issue to no test: the run fails, while the test itself passes. A failure
/// with no test at all, current or creating, goes to XCTest only: XCTest doesn't say which test is running, and
/// Xcode's interop reports an issue recorded during an XCTest test as a second failure of that test.
func reportFailure(_ message: String, at sourceLocation: SourceLocation?, creatingTest: CreatingTest? = nil) {
    let configuration = CuckooConfiguration.current
    if let handler = configuration.failureHandler {
        handler(ReportedFailure(message: message, sourceLocation: sourceLocation, creatingTest: creatingTest))
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
