import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A `~Copyable` argument is recorded as a `NoncopyableArgument` placeholder, matched with `any()`, and a `then` closure
/// borrows the argument itself.
struct NoncopyableArgumentTests {
    private enum TestError: Error {
        case unknown
    }

    @Test
    func stubAndVerifyNoncopyableArguments() {
        let mock = MockTicketOffice()
        stub(mock) { stub in
            when(stub.redeem(any(), guest: any())).thenReturn(false)
            when(stub.redeem(any(), guest: "Ada")).thenReturn(true)
            when(stub.peek(any())).thenReturn(7)
            when(stub.hold(any())).thenDoNothing()
        }

        // `#expect` would copy the arguments of a call it's given, so the calls happen outside it.
        let adaRedeemed = mock.redeem(Ticket(seat: 1), guest: "Ada")
        let bobRedeemed = mock.redeem(Ticket(seat: 2), guest: "Bob")
        #expect(adaRedeemed)
        #expect(!bobRedeemed)
        // A borrowed argument stays the caller's.
        let ticket = Ticket(seat: 3)
        let seatCount = mock.peek(ticket)
        #expect(seatCount == 7)
        mock.hold(Ticket(seat: 4))
        mock.hold(ticket)

        verify(mock).redeem(any(), guest: "Ada")
        verify(mock, times(2)).redeem(any(), guest: any())
        verify(mock).peek(any())
        verify(mock, times(2)).hold(any())
        verifyNoMoreInteractions(mock)
    }

    @Test
    func thenBorrowsTheArgument() async throws {
        let mock = MockTicketOffice()
        stub(mock) { stub in
            when(stub.redeem(any(), guest: any())).then { ticket, guest in
                ticket.seat == 1 && guest == "Ada"
            }
            when(stub.peek(any())).then { ticket in ticket.seat * 10 }
            when(stub.upgrade(any(), to: any())).then { ticket, row in
                // An optional `~Copyable` value is read with a borrowing `switch`; `?.` would consume it.
                switch ticket {
                case .some(let ticket): ticket.seat + row
                case .none: throw TestError.unknown
                }
            }
        }

        let adaRedeemed = mock.redeem(Ticket(seat: 1), guest: "Ada")
        let bobRedeemed = mock.redeem(Ticket(seat: 2), guest: "Ada")
        #expect(adaRedeemed)
        #expect(!bobRedeemed)
        // A borrowed argument stays the caller's after the stub has read it.
        let ticket = Ticket(seat: 3)
        let peeked = mock.peek(ticket)
        #expect(peeked == 30)
        #expect(ticket.seat == 3)
        let upgraded = try await mock.upgrade(Ticket(seat: 4), to: 20)
        #expect(upgraded == 24)
        await #expect(throws: TestError.unknown) { try await mock.upgrade(nil, to: 1) }
    }

    /// A generic `~Copyable` argument's type isn't known to the stub, so `then` receives the placeholder.
    @Test
    func thenReceivesThePlaceholderOfAGenericArgument() {
        let mock = MockTicketOffice()
        let held = Locked<[String]>([])
        stub(mock) { stub in
            when(stub.hold(any())).then { value in held.withLock { $0.append(value.description) } }
        }

        mock.hold(Ticket(seat: 1))
        #expect(held.withLock { $0 } == ["<~Copyable T>"])
        #expect(NoncopyableArgument(type: "Ticket").description == "<~Copyable Ticket>")
    }

    @Test
    func actorMocksRecordNoncopyableArguments() async {
        let mock = MockTicketDesk()
        stub(mock) { stub in
            when(stub.stamp(any())).then { _, ticket in "stamped \(ticket.seat)" }
        }

        #expect(await mock.stamp(Ticket(seat: 1)) == "stamped 1")
        verify(mock).stamp(any())
    }

    @Test
    func classMocksStubNoncopyableArguments() {
        let mock = MockTicketShredder()
        stub(mock) { stub in
            when(stub.shred(any())).then { ticket in -ticket.seat }
        }

        #expect(mock.shred(Ticket(seat: 5)) == -5)
        verify(mock).shred(any())
    }
}
