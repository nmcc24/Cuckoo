/// Checks that the calls verified in `block` happened in the order of the `verify` calls, across mocks.
///
/// ```swift
/// inOrder {
///     verify(database).open()
///     verify(cache, times(2)).store(any())
///     verify(database).close()
/// }
/// ```
///
/// Each `verify` looks only at the calls made after the ones the previous `verify` matched, and takes the fewest
/// of them its call matcher accepts. `never()` and `atMost(_:)` look at all of them. Other calls may come in
/// between, unless `strict` is `true`: then the verified calls of the mocks verified in `block` must follow each
/// other, with no other call to those mocks in between.
public func inOrder(
    strict: Bool = false,
    file: StaticString = #file,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column,
    _ block: () -> Void
) {
    let order = InOrder()
    InOrder.$current.withValue(order) {
        block()
    }
    if strict {
        order.checkNothingInBetween(at: (file, fileID, filePath, line, column))
    }
}

/// Numbers every recorded call across all mocks, so `inOrder` can compare calls to different mocks.
enum CallSequence {
    private static let last = Locked(0)

    static func next() -> Int {
        last.withLock { last in
            last += 1
            return last
        }
    }
}

/// A recorded call with its place in `CallSequence`.
struct SequencedCall {
    let sequence: Int
    let call: any StubCall
}

/// The state of one `inOrder` block: how far its `verify` calls have got, and what they matched.
final class InOrder: Sendable {
    @TaskLocal static var current: InOrder?

    private struct State {
        /// The sequence number of the last call the previous `verify` matched.
        var cursor = 0
        var managers: [ObjectIdentifier: MockManager] = [:]
        var verifiedSequences: Set<Int> = []
    }

    private let state = Locked(State())

    var cursor: Int {
        state.withLock { $0.cursor }
    }

    /// Moves past `calls`, which a `verify` in the block matched.
    func advance(past calls: [SequencedCall], of manager: MockManager) {
        state.withLock { state in
            state.managers[ObjectIdentifier(manager)] = manager
            state.verifiedSequences.formUnion(calls.map(\.sequence))
            if let last = calls.last {
                state.cursor = last.sequence
            }
        }
    }

    /// Notes a mock whose `verify` failed, so the failure can list its calls.
    func involve(_ manager: MockManager) {
        state.withLock { $0.managers[ObjectIdentifier(manager)] = manager }
    }

    /// The calls to the mocks verified so far, in the order they were made, one per line. `→` marks where the
    /// next `verify` starts looking.
    func describeCalls() -> String {
        let (managers, cursor) = state.withLock { (Array($0.managers.values), $0.cursor) }
        let calls = managers.flatMap { $0.sequencedCalls() }.sorted { $0.sequence < $1.sequence }
        guard !calls.isEmpty else {
            return "No calls were made to the mocks verified in order."
        }
        return "Calls to the mocks verified in order:\n" + calls.map { call in
            (call.sequence > cursor ? "→ " : "  ") + call.call.readableDescription
        }.joined(separator: "\n")
    }

    /// Reports the calls to the verified mocks that came between the first and the last verified call but weren't
    /// verified themselves.
    func checkNothingInBetween(at sourceLocation: SourceLocation) {
        let (managers, verified) = state.withLock { (Array($0.managers.values), $0.verifiedSequences) }
        guard let first = verified.min(), let last = verified.max() else {
            return
        }
        let unverified = managers
            .flatMap { $0.sequencedCalls() }
            .filter { (first...last).contains($0.sequence) && !verified.contains($0.sequence) }
            .sorted { $0.sequence < $1.sequence }
        guard !unverified.isEmpty else {
            return
        }
        let calls = unverified.map { "  " + $0.call.readableDescription }.joined(separator: "\n")
        reportFailure("Wanted the verified calls in strict order, but these calls came in between:\n" + calls, at: sourceLocation)
    }
}

extension CallMatcher {
    /// The fewest of `calls`, from the first, that this matcher accepts. A matcher that accepts no calls, like
    /// `never()` or `atMost(_:)`, has to accept all of them. `nil` if it accepts none of these prefixes.
    func acceptedPrefix<Call>(of calls: [Call], callOf: (Call) -> any StubCall) -> ArraySlice<Call>? {
        let stubCalls = calls.map(callOf)
        if matches([]) {
            return matches(stubCalls) ? calls[...] : nil
        }
        for count in stride(from: 1, through: calls.count, by: 1) where matches(Array(stubCalls.prefix(count))) {
            return calls.prefix(count)
        }
        return nil
    }
}
