import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct ArgumentCaptorTest {
    @Test
    func multipleCalls() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.readWriteProperty.set(anyInt())).thenDoNothing()
        }
        mock.readWriteProperty = 10
        mock.readWriteProperty = 20
        mock.readWriteProperty = 30
        let captor = ArgumentCaptor<Int>()
        
        verify(mock, times(3)).readWriteProperty.set(captor.capture())
        
        #expect(captor.value == 30)
        #expect(captor.allValues == [10, 20, 30])
    }

    @Test
    func noCall() {
        let mock = MockTestedClass()
        let captor = ArgumentCaptor<Int>()
        
        verify(mock, never()).readWriteProperty.set(captor.capture())
        
        #expect(captor.value == nil)
        #expect(captor.allValues.isEmpty)
    }

    @Test
    func isSendableWhenItsValuesAre() {
        let captor: any Sendable = ArgumentCaptor<Int>()
        #expect(captor is ArgumentCaptor<Int>)
    }
}
