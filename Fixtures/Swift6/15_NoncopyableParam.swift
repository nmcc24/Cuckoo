struct Token: ~Copyable { var id: Int }
enum Ticket: ~Copyable { case single, group(Int) }

protocol Consumer {
    func consume(_ token: consuming Token)
    func inspect(_ token: borrowing Token) -> Int
    func redeem(_ ticket: consuming Ticket?, seat: Int) async throws -> String
    func take<T: ~Copyable>(_ value: consuming T) -> Bool
    func check<T>(_ value: borrowing T, label: String) -> Bool where T: ~Copyable
    // A closure taking a `~Copyable` value is itself copyable, so it's recorded as usual.
    func visit(_ visitor: (borrowing Token) -> Void)
}

protocol TokenVault: Actor {
    func deposit(_ token: consuming Token, note: String)
}

class Shredder {
    init() {}
    func shred(_ token: consuming Token) -> Int { token.id }
}
