/// The stubbing handle of a member that returns nothing.
public protocol StubFunctionThenDoNothingTrait: BaseStubFunctionTrait {
    /// Makes matching calls return without doing anything.
    func thenDoNothing() -> Self
}

public extension StubFunctionThenDoNothingTrait where OutputType == Void {
    /// Makes matching calls return without doing anything.
    @discardableResult
    func thenDoNothing() -> Self {
        stub.appendAction(.returnValue(Void()))
        return self
    }
}
