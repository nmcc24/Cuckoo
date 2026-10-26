struct Ticket: ~Copyable {
    let seat: Int
}

protocol TicketOffice {
    func redeem(_ ticket: consuming Ticket, guest: String) -> Bool
    func peek(_ ticket: borrowing Ticket) -> Int
    func hold<T: ~Copyable>(_ value: consuming T)
}

protocol TicketDesk: Actor {
    func stamp(_ ticket: borrowing Ticket) -> String
}

class TicketShredder {
    init() {}

    func shred(_ ticket: consuming Ticket) -> Int {
        ticket.seat
    }
}
