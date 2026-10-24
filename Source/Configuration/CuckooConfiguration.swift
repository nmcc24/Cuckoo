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
/// throws `any Error` throws `CuckooError.unstubbedCall`, and any other member returns its type's default value.
/// It crashes only when neither is possible.
public struct CuckooConfiguration: Sendable {
    /// Receives each failure instead of the test framework. `nil` reports to the framework running the test.
    public typealias FailureHandler = @Sendable (_ message: String, _ sourceLocation: SourceLocation) -> Void

    /// Default values that take precedence over `DefaultValueRegistry` for this scope.
    public var defaultValues: DefaultValues
    public var failureHandler: FailureHandler?

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

    public init() {
    }

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
func reportFailure(_ message: String, at sourceLocation: SourceLocation) {
    if let handler = CuckooConfiguration.current.failureHandler {
        handler(message, sourceLocation)
        return
    }
    #if canImport(Testing)
    if Test.current != nil {
        Issue.record(
            Comment(rawValue: message),
            sourceLocation: Testing.SourceLocation(
                fileID: sourceLocation.fileID,
                filePath: sourceLocation.filePath,
                line: sourceLocation.line,
                column: sourceLocation.column
            )
        )
        return
    }
    #endif
    #if canImport(XCTest)
    XCTFail(message, file: sourceLocation.file, line: UInt(sourceLocation.line))
    #else
    print("Cuckoo failure:", message, sourceLocation)
    #endif
}
