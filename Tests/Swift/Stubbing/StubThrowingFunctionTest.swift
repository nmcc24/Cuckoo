import Foundation
import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

struct StubThrowingFunctionTest {
    @Test
    func then() throws {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withThrows()).then {
                return 2
            }
        }

        #expect(try! mock.withThrows() == 2)
    }

    @Test
    func thenReturn() throws {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withThrows()).thenReturn(2)
        }
        
        #expect(try! mock.withThrows() == 2)
    }

    @Test
    func thenCallRealImplementation() throws {
        let mock = MockTestedClass().withEnabledSuperclassSpy()
        stub(mock) { mock in
            when(mock.withThrows()).thenCallRealImplementation()
        }
        
        #expect(try! mock.withThrows() == 0)
    }

    @Test
    func thenThrow() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withThrows()).thenThrow(TestError.unknown)
        }

        var catched = false
        do {
            _ = try mock.withThrows()
        } catch {
            catched = true
        }

        #expect(catched)
    }

    @Test
    func overrideThenThrowInSubClass() {
        let mock = MockTestedSubclass()

        stub(mock) { mock in
            when(mock.withThrows()).thenThrow(TestError.unknown)
        }

        var catched = false
        do {
            _ = try mock.withThrows()
        } catch {
            catched = true
        }

        #expect(catched)
    }
    
    @Test
    func typedThrowsThenTypedError() {
        let mock = MockTestedClass()
        stub(mock) { mock in
            when(mock.withTypedThrows())
                .thenThrow(NSError(domain: "StubThrowingFunctionTest", code: 0))
        }

        #expect(throws: NSError(domain: "StubThrowingFunctionTest", code: 0)) {
            try mock.withTypedThrows()
        }
    }

    private enum TestError: Error {
        case unknown
    }
}
