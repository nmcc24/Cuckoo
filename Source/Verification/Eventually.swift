/// Runs `block` until it records no failure, for code that calls a mock from another task.
///
/// The block's failures are held back while it's retried: every `pollingInterval`, until `timeout` runs out. If it
/// still fails then, or the waiting task is cancelled, the last run's failures are reported at their own source
/// locations. Only Cuckoo's failures are retried; an `#expect` or `XCTAssert` in the block reports at once.
///
/// ```swift
/// viewModel.refresh() // starts a Task that calls the service
/// await eventually {
///     verify(service).fetch(any())
/// }
/// ```
///
/// It checks that something becomes true. `verify(mock, never())` in the block passes on the first run, before
/// the code under test has had a chance to call the mock.
public nonisolated(nonsending) func eventually(
    timeout: Duration = .seconds(1),
    pollingInterval: Duration = .milliseconds(10),
    _ block: () -> Void
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while true {
        let failures = collectingFailures(of: block)
        guard !failures.isEmpty else {
            return
        }
        let remaining = clock.now.duration(to: deadline)
        guard remaining > .zero, !Task.isCancelled else {
            for failure in failures {
                reportFailure("Still failing after \(timeout): \(failure.message)", at: failure.sourceLocation)
            }
            return
        }
        // A cancelled sleep ends early; the next run then reports what still fails.
        try? await Task.sleep(for: min(pollingInterval, remaining), clock: clock)
    }
}

/// Runs `block` with a failure handler that keeps its failures instead of reporting them.
private func collectingFailures(of block: () -> Void) -> [(message: String, sourceLocation: SourceLocation)] {
    let failures = Locked<[(message: String, sourceLocation: SourceLocation)]>([])
    var configuration = CuckooConfiguration.current
    configuration.failureHandler = { message, sourceLocation in
        failures.withLock { $0.append((message, sourceLocation)) }
    }
    CuckooConfiguration.$current.withValue(configuration) {
        block()
    }
    return failures.withLock { $0 }
}
