import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct ConstrainedAssociatedTypesTest {
    @Test
    func stubsAndVerifiesAMockWhoseAssociatedTypesHaveWhereClauses() {
        let mock = MockConstrainedAssociatedTypes<String, [Int]>()
        stub(mock) { stub in
            when(stub.echo(equal(to: "ping"))).thenReturn("pong")
            when(stub.first(of: equal(to: [4, 5]))).then { items in items.first }
        }

        #expect(mock.echo("ping") == "pong")
        #expect(mock.first(of: [4, 5]) == 4)

        verify(mock).echo(equal(to: "ping"))
        verify(mock).first(of: equal(to: [4, 5]))
        verifyNoMoreInteractions(mock)
    }
}
