/// A store the ledger reads balances from. Its target uses a synchronized folder, as new Xcode projects do.
public protocol BalanceStore {
    func balance(of account: String) -> Int
}

public struct Ledger {
    let store: any BalanceStore

    public init(store: any BalanceStore) {
        self.store = store
    }

    public func total(of accounts: [String]) -> Int {
        accounts.map(store.balance(of:)).reduce(0, +)
    }
}
