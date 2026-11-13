/// A type that records its calls and stubs in a ``MockManager``. Every generated mock conforms.
public protocol HasMockManager {
    /// The manager holding this mock's stubs and recorded calls.
    var cuckoo_manager: MockManager { get }
}

/// A type that says whether it has a real implementation to call, as a class mock's superclass.
public protocol HasSuperclass {
    /// Whether the mocked type is a class, whose real implementation the mock can call.
    static var cuckoo_hasSuperclass: Bool { get }
}

/// A generated mock of a protocol or class.
///
/// The generator writes the conformance; tests use a mock through ``stub(_:block:)-(M,_)``, ``verify(_:_:fileID:filePath:line:column:)->M.Verification``
/// and ``Mock/enableDefaultImplementation(_:)``.
public protocol Mock: HasMockManager, HasSuperclass {
    /// The mocked protocol or class.
    associatedtype MocksType
    /// The proxy ``stub(_:block:)-(M,_)`` hands to its block, with one stubbing member per mocked member.
    associatedtype Stubbing: StubbingProxy
    /// The proxy ``verify(_:_:fileID:filePath:line:column:)->M.Verification`` returns, with one verifying member per mocked member.
    associatedtype Verification: VerificationProxy

    /// Returns the proxy for stubbing this mock's members.
    func getStubbingProxy() -> Stubbing

    /// Returns the proxy that checks this mock's calls against `callMatcher`, reporting failures at `sourceLocation`.
    func getVerificationProxy(_ callMatcher: CallMatcher, sourceLocation: SourceLocation) -> Verification

    /// Makes every unstubbed member forward to `stub`, so the mock behaves like that implementation while still
    /// recording calls.
    ///
    /// A value-type `stub` is copied once: the mock keeps the changes made through it, and later changes to the
    /// original don't reach it. Pass a class instance to share state with the test.
    func enableDefaultImplementation(_ stub: MocksType)
}

public extension Mock {
    /// Returns the proxy for stubbing this mock's members.
    func getStubbingProxy() -> Stubbing {
        Stubbing(manager: cuckoo_manager)
    }
    
    /// Returns the proxy that checks this mock's calls against `callMatcher`, reporting failures at `sourceLocation`.
    func getVerificationProxy(_ callMatcher: CallMatcher, sourceLocation: SourceLocation) -> Verification {
        Verification(manager: cuckoo_manager, callMatcher: callMatcher, sourceLocation: sourceLocation)
    }

    /// Calls ``Mock/enableDefaultImplementation(_:)`` and returns the mock, for use in an initializer chain.
    func withEnabledDefaultImplementation(_ stub: MocksType) -> Self {
        enableDefaultImplementation(stub)
        return self
    }
}

/// A generated mock of a protocol.
public protocol ProtocolMock: Mock { }

/// A generated mock of a class, which subclasses it.
public protocol ClassMock: Mock {
    /// Makes every unstubbed member call the superclass's real implementation, while still recording calls.
    func enableSuperclassSpy()
}

public extension ClassMock {
    /// Makes every unstubbed member call the superclass's real implementation, while still recording calls.
    func enableSuperclassSpy() {
        cuckoo_manager.enableSuperclassSpy()
    }

    /// Calls ``ClassMock/enableSuperclassSpy()`` and returns the mock, for use in an initializer chain.
    func withEnabledSuperclassSpy() -> Self {
        enableSuperclassSpy()
        return self
    }
}

public extension ClassMock {
    /// `true`: a class mock can call its superclass.
    static var cuckoo_hasSuperclass: Bool {
        true
    }
}

public extension ProtocolMock {
    /// `false`: a protocol has no implementation to call.
    static var cuckoo_hasSuperclass: Bool {
        false
    }
}
