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
    private var values: [ObjectIdentifier: any Sendable] = [:]

    /// Creates an empty set of default values.
    public init() {
    }

    /// Registers `value` as the default for `type` in this set.
    public mutating func register<T: Sendable>(_ value: T, for type: T.Type = T.self) {
        // Boxed explicitly, so a registered `nil` is stored rather than removing the entry.
        let boxed: any Sendable = value
        values[ObjectIdentifier(type)] = boxed
    }

    func value<T>(for type: T.Type) -> T? {
        guard let value = values[ObjectIdentifier(type)] else {
            return nil
        }
        return value as? T
    }
}

/// Errors a mock throws on its own.
public enum CuckooError: Error, Sendable, Equatable {
    /// A throwing member was called with no matching stub.
    case unstubbedCall(method: String)
}

/// Reports a failure to the current configuration's handler, or else to the framework running the current test
/// only. Swift Testing flags an `XCTFail` inside its tests, and XCTest doesn't see Swift Testing issues.
///
/// A failure with no `sourceLocation`, such as an unstubbed call, which happens inside the mock, is reported at the
/// Swift Testing test. Elsewhere it has no better place than this function.
func reportFailure(_ message: String, at sourceLocation: SourceLocation?) {
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
    if let test = Test.current {
        Issue.record(
            Comment(rawValue: message),
            sourceLocation: sourceLocation.map { sourceLocation in
                Testing.SourceLocation(
                    fileID: sourceLocation.fileID,
                    filePath: "\(sourceLocation.filePath)",
                    line: sourceLocation.line,
                    column: sourceLocation.column
                )
            } ?? test.sourceLocation
        )
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
