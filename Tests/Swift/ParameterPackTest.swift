import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A parameter pack is recorded as one `ParameterPack`, matched with `anyPack()`, `equal(toPack:)` or a closure.
struct ParameterPackTests {
    private enum TestError: Error {
        case failed
    }

    @Test
    func stubAndVerifyAPack() {
        let mock = MockParameterPackProtocol()
        stub(mock) { stub in
            when(stub.count(anyPack())).thenReturn(0)
            when(stub.count(equal(toPack: 1, "a"))).thenReturn(2)
        }

        #expect(mock.count(1, "a") == 2)
        #expect(mock.count("a", 1) == 0)
        #expect(mock.count() == 0)

        verify(mock).count(equal(toPack: 1, "a"))
        verify(mock).count(equal(toPack: "a", 1))
        verify(mock, times(3)).count(anyPack())
        verify(mock, never()).count(equal(toPack: 1))
    }

    @Test
    func packReturnedThroughThen() {
        let mock = MockParameterPackProtocol()
        stub(mock) { stub in
            when(stub.combine(anyPack())).then { (pack: ParameterPack) -> (Int, String) in
                (pack[0] as! Int * 2, "\(pack[1])!")
            }
        }

        let (number, text) = mock.combine(21, "hi")

        #expect(number == 42)
        #expect(text == "hi!")
        verify(mock).combine(ParameterMatcher { $0.count == 2 })
    }

    @Test
    func packAfterAnotherParameter() {
        let mock = MockParameterPackProtocol()
        var logged: [String] = []
        stub(mock) { stub in
            when(stub.log(any(), anyPack())).then { prefix, pack in logged.append("\(prefix) \(pack)") }
        }

        mock.log("values:", 1, true, "x")

        #expect(logged == ["values: (1, true, x)"])
        verify(mock).log("values:", equal(toPack: 1, true, "x"))
    }

    @Test
    func asyncThrowingPack() async throws {
        let mock = MockParameterPackProtocol()
        stub(mock) { stub in
            when(stub.describe(anyPack())).then { pack in pack.values.map { "\($0)" }.joined(separator: "+") }
            when(stub.describe(equal(toPack: 0))).thenThrow(TestError.failed)
        }

        #expect(try await mock.describe(1, "b") == "1+b")
        await #expect(throws: TestError.self) { try await mock.describe(0) }
        verify(mock, times(2)).describe(anyPack())
    }

    @Test
    func classPackMethodsKeepTheRealImplementation() {
        let mock = MockParameterPackClass()
        stub(mock) { stub in
            when(stub.name()).thenReturn("stubbed")
        }

        #expect(mock.count(1, 2, 3) == 3)
        #expect(mock.name() == "stubbed")
    }

    @Test
    func defaultImplementationGetsThePack() {
        final class Implementation: ParameterPackProtocol {
            func combine<each T>(_ values: repeat each T) -> (repeat each T) {
                (repeat each values)
            }

            func count<each T>(_ values: repeat each T) -> Int {
                ParameterPack(repeat each values).count
            }

            func log<each T>(_ prefix: String, _ values: repeat each T) {
            }

            func describe<each T: CustomStringConvertible>(_ values: repeat each T) async throws -> String {
                ""
            }
        }
        let mock = MockParameterPackProtocol()
        mock.enableDefaultImplementation(Implementation())

        #expect(mock.count(1, 2) == 2)
        #expect(mock.combine(1, "a") == (1, "a"))
        verify(mock).count(anyPack())
    }

    @Test
    func packDescription() {
        #expect(ParameterPack(1, "a", nil as Int?).description == "(1, a, nil)")
        #expect(ParameterPack().count == 0)
    }
}
