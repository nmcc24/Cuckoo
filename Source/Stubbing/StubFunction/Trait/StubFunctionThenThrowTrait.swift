/// The stubbing handle of a member that throws.
public protocol StubFunctionThenThrowTrait: BaseStubFunctionTrait {
    /// Makes matching calls throw `error`, then each of `errors`, one per call; the last one repeats.
    func thenThrow(_ error: ErrorType, _ errors: ErrorType...) -> Self
}

public extension StubFunctionThenThrowTrait {
    /// Makes matching calls throw `error`, then each of `errors`, one per call; the last one repeats.
    @discardableResult
    func thenThrow(_ error: ErrorType, _ errors: ErrorType...) -> Self {
        ([error] + errors).forEach { error in
            stub.appendAction(.throwError(error))
        }
        return self
    }
}
