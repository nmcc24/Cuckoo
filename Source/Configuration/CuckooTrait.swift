#if canImport(Testing)
public import Testing

/// Applies a `CuckooConfiguration` to a Swift Testing test, or to every test in a suite, and gives each test
/// (each case of a parameterized one) its own registry for static members' stubs, `StaticStubs`.
public struct CuckooTrait: TestTrait, SuiteTrait, TestScoping {
    fileprivate let configure: @Sendable (inout CuckooConfiguration) -> Void

    public var isRecursive: Bool {
        true
    }

    public func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable @concurrent () async throws -> Void
    ) async throws {
        var configuration = CuckooConfiguration.current
        configure(&configuration)
        try await CuckooConfiguration.$current.withValue(configuration) {
            try await StaticStubs.$current.withValue(StaticStubs()) {
                try await function()
            }
        }
    }
}

extension Trait where Self == CuckooTrait {
    /// Configures the mocks used by a test or suite. Arguments left `nil` keep the enclosing configuration.
    ///
    ///     @Suite(.cuckoo(defaultValues: values))
    public static func cuckoo(
        defaultValues: DefaultValues? = nil,
        failureHandler: CuckooConfiguration.FailureHandler? = nil
    ) -> Self {
        CuckooTrait { configuration in
            if let defaultValues {
                configuration.defaultValues = defaultValues
            }
            if let failureHandler {
                configuration.failureHandler = failureHandler
            }
        }
    }
}
#endif
