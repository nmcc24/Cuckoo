enum StubAction<OUT, ERROR: Error, IMPL> {
    /// A `then` closure. The mock calls it in its own isolation, so the manager never calls it directly.
    case callImplementation(IMPL)
    case returnValue(OUT)
    case throwError(ERROR)
    case callRealImplementation
}
