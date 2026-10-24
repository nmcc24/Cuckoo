import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct UnstubbedCallPolicyTests {
    @Test
    func strictRecordsAnIssueAndReturnsTheDefaultValue() {
        let mock = MockTestedProtocol()

        withKnownIssue {
            #expect(mock.count(characters: "a") == 0)
        } matching: { issue in
            issue.comments.map(\.rawValue).first?.hasPrefix("No stub for method `count(characters") == true
        }
    }

    @Test(.cuckoo(unstubbedCalls: .lenient))
    func lenientReturnsDefaultValuesSilently() {
        let mock = MockTestedProtocol()

        #expect(mock.count(characters: "a") == 0)
        #expect(mock.optionalProperty == nil)
        #expect(mock.genericReturn().isEmpty)
        #expect(mock.readOnlyProperty == "")
    }

    @Test(.cuckoo(unstubbedCalls: .lenient))
    func throwingMembersThrowUnstubbedCall() {
        let mock = MockTestedProtocol()

        #expect(throws: CuckooError.unstubbedCall(method: "withThrows() throws -> Int")) {
            try mock.withThrows()
        }
    }

    @Test(.cuckoo(unstubbedCalls: .lenient, defaultValues: {
        var values = DefaultValues()
        values.register(42)
        values.register("forty-two")
        return values
    }()))
    func traitDefaultValuesTakePrecedence() {
        let mock = MockTestedProtocol()

        #expect(mock.count(characters: "a") == 42)
        #expect(mock.readOnlyProperty == "forty-two")
        // The registry still answers types the trait doesn't cover.
        #expect(mock.optionalProperty == nil)
    }

    @Test(.cuckoo(unstubbedCalls: .lenient))
    func stubsStillWinOverDefaults() {
        let mock = MockTestedProtocol()
        stub(mock) { stub in
            when(stub.count(characters: "a")).thenReturn(7)
        }

        #expect(mock.count(characters: "a") == 7)
        #expect(mock.count(characters: "b") == 0)
    }

    @Test
    func taskLocalConfigurationAppliesInsideTheScope() async {
        var lenient = CuckooConfiguration.current
        lenient.unstubbedCalls = .lenient

        await CuckooConfiguration.$current.withValue(lenient) {
            let mock = MockTestedProtocol()
            await mock.asyncMethod()
            #expect(mock.count(characters: "a") == 0)
        }
    }
}

@Suite(.cuckoo(unstubbedCalls: .lenient))
struct CuckooTraitSuiteTests {
    @Test
    func suiteTraitAppliesToItsTests() {
        #expect(CuckooConfiguration.current.unstubbedCalls == .lenient)
    }

    @Test(.cuckoo(unstubbedCalls: .strict))
    func testTraitOverridesTheSuite() {
        #expect(CuckooConfiguration.current.unstubbedCalls == .strict)
    }
}
