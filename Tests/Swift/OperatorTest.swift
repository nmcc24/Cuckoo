import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Stubbing and verifying operators, which the proxies name `operator` plus a word for each character.
@Suite(.cuckoo())
struct OperatorTests {
    @Test
    func infixPrefixAndCustomOperators() {
        let sum = MockAmount()
        let negated = MockAmount()
        stub(MockAmount.self) { stub in
            when(stub.operatorPlus(any(), any())).thenReturn(sum)
            when(stub.prefixOperatorMinus(any())).thenReturn(negated)
            when(stub.operatorLessTildeGreater(any(), 3)).thenReturn(true)
            when(stub.operatorLessTildeGreater(any(), 4)).thenReturn(false)
        }
        let amount = MockAmount()

        #expect(amount + amount === sum)
        #expect(-amount === negated)
        #expect(amount <~> 3)
        #expect(!(amount <~> 4))

        verify(MockAmount.self).operatorPlus(any(), any())
        verify(MockAmount.self).prefixOperatorMinus(any())
        verify(MockAmount.self, times(2)).operatorLessTildeGreater(any(), any())
        verifyNoMoreInteractions(MockAmount.self)
    }

    @Test
    func inoutOperatorWritesBack() {
        let next = MockAmount()
        stub(MockAmount.self) { stub in
            when(stub.postfixOperatorPlusPlus(any())).then { value in
                value = next
            }
        }
        var amount = MockAmount()

        amount++

        #expect(amount === next)
        verify(MockAmount.self).postfixOperatorPlusPlus(any())
    }
}
