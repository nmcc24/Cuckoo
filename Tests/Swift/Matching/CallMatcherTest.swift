import XCTest
import Cuckoo

final class CallMatcherTest: XCTestCase {
    private let call = [ConcreteStubCall(method: "A", parameters: Void()) as any StubCall]
    private var multipleCalls: [any StubCall] {
        return [call[0], call[0]]
    }

    func testMatches() {
        let matcher = CallMatcher(name: "") { ($0.first?.method ?? "") == "A"}
        let nonMatchingCalls = [ConcreteStubCall(method: "B", parameters: Void()) as any StubCall]

        XCTAssertTrue(matcher.matches(call))
        XCTAssertFalse(matcher.matches(nonMatchingCalls))
    }

    func testOr() {
        let matcher = never().or(times(1))

        XCTAssertTrue(matcher.matches(call))
        XCTAssertTrue(matcher.matches([]))
        XCTAssertFalse(matcher.matches(multipleCalls))
    }

    func testAnd() {
        let matcher = atLeast(1).and(atMost(2))

        XCTAssertTrue(matcher.matches(call))
        XCTAssertTrue(matcher.matches(multipleCalls))
        XCTAssertFalse(matcher.matches([]))
    }
}
