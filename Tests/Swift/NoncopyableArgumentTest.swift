import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A `~Copyable` argument is recorded as a `NoncopyableArgument` placeholder, matched with `any()`.
struct NoncopyableArgumentTests {
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
    func thenReceivesThePlaceholder() {
        let mock = MockTicketOffice()
        stub(mock) { stub in
            when(stub.redeem(any(), guest: any())).then { ticket, guest in
                ticket == NoncopyableArgument(type: "Ticket") && guest == "Ada"
            }
            when(stub.peek(any())).then { ticket in ticket.type.count }
        }

        let redeemed = mock.redeem(Ticket(seat: 1), guest: "Ada")
        #expect(redeemed)
        #expect(mock.peek(Ticket(seat: 1)) == "Ticket".count)
        #expect(NoncopyableArgument(type: "Ticket").description == "<~Copyable Ticket>")
    }

    @Test
    func actorMocksRecordNoncopyableArguments() async {
        let mock = MockTicketDesk()
        stub(mock) { stub in
            when(stub.stamp(any())).thenReturn("stamped")
        }

        #expect(await mock.stamp(Ticket(seat: 1)) == "stamped")
        verify(mock).stamp(any())
    }

    @Test
    func classMocksStubNoncopyableArguments() {
        let mock = MockTicketShredder()
        stub(mock) { stub in
            when(stub.shred(any())).thenReturn(0)
        }

        #expect(mock.shred(Ticket(seat: 5)) == 0)
        verify(mock).shred(any())
    }
}
