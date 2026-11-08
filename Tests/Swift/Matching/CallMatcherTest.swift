import Testing
import Cuckoo

struct CallMatcherTest {
    private let call = [ConcreteStubCall(method: "A", parameters: Void()) as any StubCall]
    private var multipleCalls: [any StubCall] {
        return [call[0], call[0]]
    }

    @Test
    func matches() {
        let matcher = CallMatcher(name: "") { ($0.first?.method ?? "") == "A"}
        let nonMatchingCalls = [ConcreteStubCall(method: "B", parameters: Void()) as any StubCall]

        #expect(matcher.matches(call))
        #expect(!matcher.matches(nonMatchingCalls))
    }

    @Test
    func or() {
        let matcher = never().or(times(1))

        #expect(matcher.matches(call))
        #expect(matcher.matches([]))
        #expect(!matcher.matches(multipleCalls))
    }

    @Test
    func and() {
        let matcher = atLeast(1).and(atMost(2))

        #expect(matcher.matches(call))
        #expect(matcher.matches(multipleCalls))
        #expect(!matcher.matches([]))
    }
}
