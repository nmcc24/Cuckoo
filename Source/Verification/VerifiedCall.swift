/// The call a `verify` just checked, which ``verify(_:_:fileID:filePath:line:column:)->M.CuckooVerification`` and the
/// verification proxy's members return. `IN` holds the call's parameter types and `OUT` its return type.
///
/// Most verifications discard it. A generic member whose type comes only from its return value needs that type
/// spelled out with ``with(returnType:)``:
///
/// ```swift
/// verify(cache).value(forKey: "a").with(returnType: Int?.self)
/// ```
///
/// The `verify` counts only the calls made with that return type: `value(forKey: "a") as String?` is another call.
public struct VerifiedCall<IN, OUT>: Sendable { }

public extension VerifiedCall {
    /// Names the verified member's return type, for a generic member whose type Swift can't infer from its
    /// arguments, as in `verify(cache).value(forKey: "a").with(returnType: Int?.self)`.
    func with(returnType: OUT.Type) { }
}
