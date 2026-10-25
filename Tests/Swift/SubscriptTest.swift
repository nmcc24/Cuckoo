import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Stubbing and verifying subscripts, which mirror properties: `stub[key].get`, `stub[key].set(value)`.
struct SubscriptTests {
    private enum TestError: Error {
        case failed
    }

    @Test
    func readWriteSubscript() {
        let mock = MockSubscriptProtocol()
        var written: [String] = []
        stub(mock) { stub in
            // The latest matching stub wins, so the catch-all goes first.
            when(stub[anyString()].get).thenReturn(nil)
            when(stub["a"].get).thenReturn(1)
            when(stub[anyString()].set(any())).then { key, value in written.append("\(key)=\(value.map(String.init) ?? "nil")") }
        }

        #expect(mock["a"] == 1)
        #expect(mock["b"] == nil)
        mock["c"] = 3
        mock["d"] = nil

        #expect(written == ["c=3", "d=nil"])
        verify(mock)["a"].get()
        verify(mock, times(2))[anyString()].get()
        verify(mock)["c"].set(3)
        verify(mock)["d"].set(isNil())
        verify(mock, never())["a"].set(any())
    }

    @Test
    func readOnlySubscript() {
        let mock = MockSubscriptProtocol()
        stub(mock) { stub in
            when(stub[2].get).thenReturn("two")
        }

        #expect(mock[2] == "two")
        verify(mock)[2].get()
        verify(mock, never())[3].get()
    }

    @Test
    func labeledSubscriptWithSeveralKeys() {
        let mock = MockSubscriptProtocol()
        var written: [Double] = []
        stub(mock) { stub in
            when(stub[row: 1, column: anyInt()].get).then { row, column in Double(row * 10 + column) }
            when(stub[row: any(), column: 2].set(any())).then { _, _, value in written.append(value) }
        }

        #expect(mock[row: 1, column: 3] == 13)
        mock[row: 4, column: 2] = 0.5

        #expect(written == [0.5])
        verify(mock)[row: 1, column: 3].get()
        verify(mock)[row: 4, column: 2].set(0.5)
        verify(mock, never())[row: 4, column: 3].set(any())
    }

    @Test
    func throwingAndAsyncGetters() async throws {
        let mock = MockSubscriptProtocol()
        stub(mock) { stub in
            when(stub[failable: "ok"].get).thenReturn(1)
            when(stub[failable: "bad"].get).thenThrow(TestError.failed)
            when(stub[remote: any()].get).then { key in "remote \(key)" }
        }

        #expect(try mock[failable: "ok"] == 1)
        #expect(throws: TestError.self) { try mock[failable: "bad"] }
        #expect(await mock[remote: "x"] == "remote x")
        verify(mock, times(2))[failable: anyString()].get()
        verify(mock)[remote: "x"].get()
    }

    @Test
    func genericSubscript() {
        let mock = MockSubscriptProtocol()
        stub(mock) { stub in
            when(stub[echo: 5].get).thenReturn(50)
            when(stub[echo: "a"].get).thenReturn("b")
        }

        #expect(mock[echo: 5] == 50)
        #expect(mock[echo: "a"] == "b")
        verify(mock)[echo: 5].get()
        verify(mock, never())[echo: 6].get()
    }

    @Test
    func subscriptWithoutKeys() {
        let mock = MockSubscriptProtocol()
        stub(mock) { stub in
            when(stub[].get).thenReturn(7)
            when(stub[].set(8)).thenDoNothing()
        }

        #expect(mock[] == 7)
        mock[] = 8

        verify(mock)[].get()
        verify(mock)[].set(8)
        verify(mock, never())[].set(9)
    }

    @Test
    func opaqueParameter() {
        let mock = MockSubscriptProtocol()
        stub(mock) { stub in
            when(stub.sum(any())).then { values in values.reduce(0, +) }
        }

        #expect(mock.sum([1, 2, 3]) == 6)
        #expect(mock.sum(Set([4])) == 4)
        verify(mock, times(2)).sum(any())
    }

    @Test
    func classSubscriptCallsTheRealImplementation() {
        let mock = MockSubscriptClass()
        stub(mock) { stub in
            when(stub["a"].get).thenReturn(1)
            when(stub[anyString()].set(anyInt())).thenCallRealImplementation()
            when(stub["b"].get).thenCallRealImplementation()
            when(stub[anyInt()].get).thenCallRealImplementation()
        }

        mock["b"] = 2

        #expect(mock["a"] == 1)
        #expect(mock["b"] == 2)
        #expect(mock[4] == "4")
        verify(mock)["b"].set(2)
        verify(mock)[4].get()
    }

    @Test
    func unstubbedSubscriptFallsBackToTheDefaultImplementation() {
        let mock = MockGenericSubscriptProtocol<Int>()
        mock.enableDefaultImplementation(GenericSubscriptImplementation(["a": 1]))

        #expect(mock["a"] == 1)
        mock["b"] = 2
        #expect(mock["b"] == 2)
        #expect(mock[index: 0] != nil)
        verify(mock)["b"].set(2)
        verify(mock)[index: 0].get()
    }
}
