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
/// the code under test has had a chance to call the mock. An ``ArgumentCaptor`` captures whenever its `verify`
/// passes, so it captures again when another check in the block fails and the block runs again.
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
            // A cancelled wait ends before the timeout, so it doesn't claim the timeout passed.
            let when = Task.isCancelled ? "when the waiting task was cancelled" : "after \(timeout)"
            for failure in failures {
                reportFailure(
                    "Still failing \(when): \(failure.message)",
                    at: failure.sourceLocation,
                    creatingTest: failure.creatingTest
                )
            }
            return
        }
        // A cancelled sleep ends early; the next run then reports what still fails.
        try? await Task.sleep(for: min(pollingInterval, remaining), clock: clock)
    }
}

/// Runs `block` with a failure handler that keeps its failures instead of reporting them.
///
/// A task the block starts inherits the handler. Its failures after the block has returned would be kept where
/// nothing reads them, so they're reported the way they would have been without `eventually`.
private func collectingFailures(of block: () -> Void) -> [ReportedFailure] {
    struct Collected {
        var failures: [ReportedFailure] = []
        var isClosed = false
    }
    let collected = Locked(Collected())
    let outer = CuckooConfiguration.current
    var configuration = outer
    configuration.failureHandler = { failure in
        let isLate = collected.withLock { collected in
            guard !collected.isClosed else {
                return true
            }
            collected.failures.append(failure)
            return false
        }
        if isLate {
            CuckooConfiguration.$current.withValue(outer) {
                reportFailure(failure.message, at: failure.sourceLocation, creatingTest: failure.creatingTest)
            }
        }
    }
    CuckooConfiguration.$current.withValue(configuration) {
        block()
    }
    return collected.withLock { collected in
        collected.isClosed = true
        return collected.failures
    }
}
