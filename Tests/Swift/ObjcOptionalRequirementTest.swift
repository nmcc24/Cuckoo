#if canImport(ObjectiveC)
import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct ObjcOptionalRequirementTests {
    @Test
    func aSettableOptionalPropertyIsStubbedAndVerified() {
        let mock = MockObjcOptionalProperties()
        stub(mock) { stub in
            when(stub.count.get).thenReturn(1)
            when(stub.count.set(any())).thenDoNothing()
        }

        mock.count = 2
        #expect(mock.count == 1)
        verify(mock).count.set(2)
        verify(mock).count.get()
    }

    /// The getter reads the default implementation's value, which the protocol gives as an optional.
    @Test
    func anOptionalPropertysGetterForwardsToTheDefaultImplementation() {
        let mock = MockObjcOptionalProperties()
        mock.enableDefaultImplementation(ObjcOptionalPropertiesImplementation())

        #expect(mock.count == 5)
    }

    /// Swift can't assign to an optional requirement through its protocol, so the setter records a failure saying to
    /// stub it.
    @Test
    func anOptionalPropertysSetterRecordsAFailureInsteadOfForwarding() {
        let implementation = ObjcOptionalPropertiesImplementation()
        let mock = MockObjcOptionalProperties()
        mock.enableDefaultImplementation(implementation)

        withKnownIssue {
            mock.count = 9
        } matching: { issue in
            issue.description.contains("can't forward") && issue.description.contains("'@objc optional'")
        }
        #expect(implementation.count == 5)
    }

    @Test
    func anOptionalSubscriptIsStubbedAndVerified() {
        let mock = MockObjcOptionalProperties()
        stub(mock) { stub in
            when(stub[1].get).thenReturn("stubbed")
            when(stub[1].set(any())).thenDoNothing()
        }

        mock[1] = "written"
        #expect(mock[1] == "stubbed")
        verify(mock)[1].set("written")
        verify(mock)[1].get()
    }

    /// The getter unwraps the default implementation's value, as a property's does.
    @Test
    func anOptionalSubscriptsGetterForwardsToTheDefaultImplementation() {
        let mock = MockObjcOptionalProperties()
        mock.enableDefaultImplementation(ObjcOptionalPropertiesImplementation())

        #expect(mock[1] == "one")
    }

    @Test
    func anOptionalSubscriptsSetterRecordsAFailureInsteadOfForwarding() {
        let implementation = ObjcOptionalPropertiesImplementation()
        let mock = MockObjcOptionalProperties()
        mock.enableDefaultImplementation(implementation)

        withKnownIssue {
            mock[1] = "written"
        } matching: { issue in
            issue.description.contains("can't forward") && issue.description.contains("'@objc optional'")
        }
        #expect(implementation.names == ["zero", "one"])
    }
}
#endif
