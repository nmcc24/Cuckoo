import Testing
import Cuckoo
@testable import CuckooMocks
@_spi(CuckooTests) @testable import CuckooTestSources

/// A mock can stand for SPI members: the generated file imports the mocked module with the groups they use.
struct SPITests {
    @Test
    func spiMembersAreStubbedAndVerified() {
        let mock = MockVault()
        let token = AccessToken(value: "secret")
        stub(mock) { stub in
            when(stub.unlock(with: any())).thenReturn(false)
            when(stub.unlock(with: equal(to: token))).thenReturn(true)
        }

        #expect(mock.unlock(with: token))
        #expect(!mock.unlock(with: AccessToken(value: "wrong")))
        verify(mock).unlock(with: equal(to: token))
        verify(mock, never()).isOpen()
    }
}
