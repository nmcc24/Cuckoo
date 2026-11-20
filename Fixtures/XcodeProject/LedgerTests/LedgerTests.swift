import Cuckoo
import Testing
@testable import Ledger

@Test(.cuckoo())
func ledgerAddsTheStoresBalances() {
    let store = MockBalanceStore()
    stub(store) { stub in
        when(stub.balance(of: any())).thenReturn(2)
    }

    #expect(Ledger(store: store).total(of: ["a", "b"]) == 4)
    verify(store, times(2)).balance(of: any())
}
