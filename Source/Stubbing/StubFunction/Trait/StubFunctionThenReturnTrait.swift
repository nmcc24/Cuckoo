/// The stubbing handle of a member that returns a value.
///
/// `thenReturn` takes what the mock's ``StubSharing`` allows. Several values are returned one per call, in
/// order, and the last one repeats.
public protocol StubFunctionThenReturnTrait: BaseStubFunctionTrait {
}

public extension StubFunctionThenReturnTrait where Sharing == StubSharing.Confined {
    /// Returns `output`, then each of `outputs`, one per call; the last one repeats.
    @discardableResult
    func thenReturn(_ output: OutputType, _ outputs: OutputType...) -> Self {
        thenReturn(inOrder: [output] + outputs)
    }

    /// Returns `outputs` in order, one per call, then repeats the last one.
    @discardableResult
    func thenReturn(inOrder outputs: [OutputType]) -> Self {
        for output in outputs {
            stub.appendAction(.returnValue(output))
        }
        return self
    }
}

public extension StubFunctionThenReturnTrait where Sharing == StubSharing.Shared, OutputType: Sendable {
    /// Returns `output`, then each of `outputs`, one per call; the last one repeats. Calls can come from any task,
    /// so the values must be `Sendable`.
    @discardableResult
    func thenReturn(_ output: OutputType, _ outputs: OutputType...) -> Self {
        thenReturn(inOrder: [output] + outputs)
    }

    /// Returns `outputs` in order, one per call, then repeats the last one.
    @discardableResult
    func thenReturn(inOrder outputs: [OutputType]) -> Self {
        for output in outputs {
            stub.appendAction(.returnValue(output))
        }
        return self
    }
}

public extension StubFunctionThenReturnTrait where Sharing == StubSharing.Isolated {
    /// Returns `output` for every matching call. It's sent to the mock's actor, where every call runs.
    @discardableResult
    func thenReturn(_ output: sending OutputType) -> Self {
        stub.appendAction(.returnValue(output))
        return self
    }

    /// Returns `outputs` in order, then repeats the last one. They're sent to the mock's actor.
    @discardableResult
    func thenReturn(inOrder outputs: sending [OutputType]) -> Self {
        for output in outputs {
            stub.appendAction(.returnValue(output))
        }
        return self
    }
}

public extension StubFunctionThenReturnTrait where Sharing == StubSharing.Isolated, OutputType: Sendable {
    /// Returns `output`, then each of `outputs`, one per call; the last one repeats.
    @discardableResult
    func thenReturn(_ output: OutputType, _ outputs: OutputType...) -> Self {
        thenReturn(inOrder: [output] + outputs)
    }
}
