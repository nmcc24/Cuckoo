import Cuckoo
import Testing
@testable import Shop

@MainActor
@Test(.cuckoo())
func checkoutShowsTheTotalAndCharges() async {
    let view = MockCartView()
    let payments = MockPaymentService()
    stub(view) { stub in
        when(stub.show(total: any())).thenDoNothing()
    }
    stub(payments) { stub in
        when(stub.charge(cents: 250)).thenReturn("receipt-1")
    }

    let receipt = await Checkout(view: view, payments: payments).pay(cents: 250)

    #expect(receipt == "receipt-1")
    verify(view).show(total: 250)
    verify(payments).charge(cents: 250)
}

@MainActor
@Test(.cuckoo())
func aDeclinedPaymentGivesNoReceipt() async {
    let view = MockCartView()
    let payments = MockPaymentService()
    stub(view) { stub in
        when(stub.show(total: any())).thenDoNothing()
    }
    stub(payments) { stub in
        when(stub.charge(cents: any())).thenThrow(PaymentError.declined)
    }

    #expect(await Checkout(view: view, payments: payments).pay(cents: 100) == nil)
}
