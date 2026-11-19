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
/// The `verify` calls are checked when the block ends. Each one looks only at the calls made after the ones the
/// previous `verify` took. It takes all of its matching calls there if its call matcher accepts them all, such as
/// `atLeast(2)` on three calls. Otherwise it takes only the first run of matching calls that no other call to the
/// mocks verified in `block` interrupts, if its call matcher accepts that run: `times(2)` passes on two calls in a
/// row even when the same call comes again later, which a later `verify` can then take, but `times(1)` fails on two
/// calls in a row, as it does outside `inOrder`. Other calls may come between the verified calls, unless `strict`
/// is `true`: then the verified calls of the mocks verified in `block` must follow each other, with no other call
/// to those mocks in between.
public func inOrder(
    strict: Bool = false,
    fileID: String = #fileID,
    filePath: StaticString = #filePath,
    line: Int = #line,
    column: Int = #column,
    _ block: () -> Void
) {
    let order = InOrder()
    InOrder.$current.withValue(order) {
        block()
    }
    order.checkSteps()
    if strict {
        order.checkNothingInBetween(at: (fileID, filePath, line, column))
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

/// One `verify` inside an `inOrder` block, checked when the block ends.
struct InOrderStep {
    /// The verified mock's manager.
    let manager: MockManager
    /// The mock's calls that match the verified member and arguments.
    let matching: [SequencedCall]
    let callMatcher: CallMatcher
    let sourceLocation: CuckooSourceLocation
    /// Marks the calls with these sequence numbers as verified, which the step took.
    let take: (Set<Int>) -> Void
}

/// The state of one `inOrder` block: its `verify` calls, then how far checking them has got.
final class InOrder: Sendable {
    @TaskLocal static var current: InOrder?

    /// A check from the block, run in order when it ends.
    private enum Check {
        case verify(InOrderStep)
        /// A `verifyNoMoreInteractions`, which runs after the `verify` calls before it took their calls.
        case deferred(@Sendable () -> Void)
    }

    private struct State {
        var checks: [Check] = []
        /// The managers of the mocks verified in the block, in the order of their first `verify`.
        var managers: [MockManager] = []
        var verifiedSequences: Set<Int> = []
        /// Whether the block has ended and its checks have run. A check added later, from a task the block started,
        /// would never run.
        var isChecked = false
    }

    private let state = Locked(State())

    /// Adds a `verify` from the block, to check when it ends.
    func add(_ step: InOrderStep) {
        let isChecked = state.withLock { state in
            guard !state.isChecked else {
                return true
            }
            state.checks.append(.verify(step))
            if !state.managers.contains(where: { $0 === step.manager }) {
                state.managers.append(step.manager)
            }
            return false
        }
        if isChecked {
            Self.reportLate("verify(\(step.callMatcher.name))", at: step.sourceLocation, creatingTest: step.manager.creatingTest)
        }
    }

    /// Adds a check that must wait for the block's earlier `verify` calls, such as `verifyNoMoreInteractions`.
    func addDeferred(at sourceLocation: CuckooSourceLocation, creatingTest: CreatingTest?, _ check: @escaping @Sendable () -> Void) {
        let isChecked = state.withLock { state in
            guard !state.isChecked else {
                return true
            }
            state.checks.append(.deferred(check))
            return false
        }
        if isChecked {
            Self.reportLate("verifyNoMoreInteractions", at: sourceLocation, creatingTest: creatingTest)
        }
    }

    private static func reportLate(_ check: String, at sourceLocation: CuckooSourceLocation, creatingTest: CreatingTest?) {
        reportFailure(
            "\(check) ran after its inOrder block ended, so it wasn't checked. Wait for the task that runs it inside the block.",
            at: sourceLocation,
            creatingTest: creatingTest
        )
    }

    /// Checks the block's `verify` calls in order, reporting each one that fails, and runs its deferred checks
    /// where they were made.
    func checkSteps() {
        let (checks, managers) = state.withLock { state in
            state.isChecked = true
            return (state.checks, state.managers)
        }
        // The sequence number of the last call the previous passing `verify` took.
        var cursor = 0
        for check in checks {
            guard case .verify(let step) = check else {
                if case .deferred(let run) = check {
                    run()
                }
                continue
            }
            let candidates = step.matching.filter { $0.sequence > cursor }
            guard let taken = taken(by: step, from: candidates, after: cursor, managers: managers) else {
                let involved = Array(managers.prefix { $0 !== step.manager }) + [step.manager]
                let verified = state.withLock { $0.verifiedSequences }
                let message = "Wanted \(step.callMatcher.name) in order but invoked \(timesDescription(candidates.count)) after the previous verification (\(timesDescription(step.matching.count)) in all)."
                reportFailure(
                    message + "\n" + Self.describeCalls(of: involved, after: cursor, verified: verified),
                    at: step.sourceLocation,
                    creatingTest: step.manager.creatingTest
                )
                continue
            }
            let sequences = Set(taken.map(\.sequence))
            step.take(sequences)
            state.withLock { $0.verifiedSequences.formUnion(sequences) }
            if let last = taken.last {
                cursor = last.sequence
            }
        }
    }

    /// The calls of `candidates` a step takes: all of them if its call matcher accepts them all, else the first run of
    /// them that no other call to `managers` interrupts, if it accepts that. `nil` if it accepts neither.
    private func taken(by step: InOrderStep, from candidates: [SequencedCall], after cursor: Int, managers: [MockManager]) -> [SequencedCall]? {
        if step.callMatcher.matches(candidates.map(\.call)) {
            return candidates
        }
        let candidateSequences = Set(candidates.map(\.sequence))
        let callsAfterCursor = managers
            .flatMap { $0.sequencedCalls() }
            .filter { $0.sequence > cursor }
            .sorted { $0.sequence < $1.sequence }
        let firstRun = Array(callsAfterCursor
            .drop { !candidateSequences.contains($0.sequence) }
            .prefix { candidateSequences.contains($0.sequence) })
        guard !firstRun.isEmpty, step.callMatcher.matches(firstRun.map(\.call)) else {
            return nil
        }
        return firstRun
    }

    /// The calls to `managers`' mocks, in the order they were made, one per line. `→` marks the calls after
    /// `cursor`, where the failed `verify` looked, and `✓` the calls an earlier `verify` in the block took.
    private static func describeCalls(of managers: [MockManager], after cursor: Int, verified: Set<Int>) -> String {
        let calls = managers.flatMap { $0.sequencedCalls() }.sorted { $0.sequence < $1.sequence }
        guard !calls.isEmpty else {
            return "No calls were made to the mocks verified in order."
        }
        let lines = calls.map { call in
            let mark = verified.contains(call.sequence) ? "✓ " : (call.sequence > cursor ? "→ " : "  ")
            return mark + call.call.readableDescription
        }
        return "Calls to the mocks verified in order (→ after the previous verification, ✓ taken by an earlier one):\n"
            + lines.joined(separator: "\n")
    }

    /// Reports the calls to the verified mocks that came between the first and the last verified call but weren't
    /// verified themselves.
    func checkNothingInBetween(at sourceLocation: CuckooSourceLocation) {
        let (managers, verified) = state.withLock { ($0.managers, $0.verifiedSequences) }
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
        reportFailure(
            "Wanted the verified calls in strict order, but these calls came in between:\n" + calls,
            at: sourceLocation,
            creatingTest: managers.lazy.compactMap(\.creatingTest).first
        )
    }
}
