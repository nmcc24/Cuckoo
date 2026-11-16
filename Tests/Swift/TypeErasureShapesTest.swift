import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A generic subscript of a protocol with an associated type reaches the default implementation.
struct TypeErasureShapesTest {
    @Test
    func genericSubscriptForwardsToTheDefaultImplementation() {
        let mock = MockKeyedStore<String>()
        mock.enableDefaultImplementation(StringKeyedStore())

        #expect(mock[7] == "value for 7")
        verify(mock)[equal(to: 7)].get()
    }

    @Test
    func genericSubscriptSetterKeepsAValueDefaultImplementationsChange() {
        let mock = MockMutableKeyedStore<String>()
        mock.enableDefaultImplementation(DictionaryKeyedStore())

        mock[1] = "one"

        #expect(mock[1] == "one")
    }

    @Test
    func asyncThrowingGetterForwardsToTheDefaultImplementation() async throws {
        let mock = MockEffectfulStore<Int>()
        mock.enableDefaultImplementation(IntEffectfulStore())

        #expect(try await mock.latest == 42)
    }

    /// An `inout` member can't reach the default implementation: the call records a failure saying to stub it, and
    /// the test goes on with the argument unchanged.
    @Test
    func unforwardableMemberRecordsAFailure() {
        let mock = MockEffectfulStore<Int>()
        mock.enableDefaultImplementation(IntEffectfulStore())
        var value = 1

        withKnownIssue {
            mock.adjust(&value)
        } matching: { issue in
            issue.description.contains("can't forward") && issue.description.contains("Stub it instead")
        }
        #expect(value == 1)
    }

    /// A member the eraser can't forward that returns a tuple records the failure and gets its elements' defaults.
    @Test
    func unforwardableMemberReturningATupleGetsItsDefault() {
        let mock = MockEffectfulStore<Int>()
        mock.enableDefaultImplementation(IntEffectfulStore())
        var value = 1

        withKnownIssue {
            #expect(mock.split(&value) == (0, ""))
        } matching: { issue in
            issue.description.contains("can't forward") && issue.description.contains("split")
        }
    }
}
