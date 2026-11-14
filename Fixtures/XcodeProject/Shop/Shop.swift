enum PaymentError: Error, Equatable {
    case declined
}

@MainActor
protocol CartView: AnyObject {
    func show(total: Int)
}

protocol PaymentService: Sendable {
    func charge(cents: Int) async throws(PaymentError) -> String
}

@MainActor
final class Checkout {
    let view: any CartView
    let payments: any PaymentService

    init(view: any CartView, payments: any PaymentService) {
        self.view = view
        self.payments = payments
    }

    func pay(cents: Int) async -> String? {
        view.show(total: cents)
        return try? await payments.charge(cents: cents)
    }
}
