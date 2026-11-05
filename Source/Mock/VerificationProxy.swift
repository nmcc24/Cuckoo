/// A generated mock's verification proxy, which ``verify(_:_:file:fileID:filePath:line:column:)->M.Verification``
/// returns. It has one verifying member per mocked member.
public protocol VerificationProxy {
    /// Creates the proxy that checks the calls `manager` recorded against `callMatcher`.
    init(manager: MockManager, callMatcher: CallMatcher, sourceLocation: SourceLocation)
}
