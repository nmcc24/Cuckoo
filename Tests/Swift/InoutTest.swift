import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// A `then` closure takes an `inout` parameter as `inout`, and what it writes reaches the caller.
struct InoutTests {
    private enum TestError: Error {
        case failed
    }

    @Test
    func thenWritesBackToTheCaller() {
        let mock = MockCounter()
        stub(mock) { stub in
            when(stub.increment(any())).then { value in value += 1 }
            when(stub.rename(any(), suffix: any())).then { name, suffix in
                name += suffix
                return name.count
            }
        }

        var count = 41
        mock.increment(&count)
        var name = "Ada"
        let length = mock.rename(&name, suffix: "!")

        #expect(count == 42)
        #expect(name == "Ada!")
        #expect(length == 4)
        verify(mock).increment(41)
        verify(mock).rename("Ada", suffix: "!")
    }

    @Test
    func thenWritesBackFromAnAsyncThrowingMember() async throws {
        let mock = MockCounter()
        stub(mock) { stub in
            when(stub.adjust(any(), by: any())).then { value, delta in
                value += delta
                return value > 0
            }
        }

        var value = -1
        let isPositive = try await mock.adjust(&value, by: 3)

        #expect(value == 2)
        #expect(isPositive)
    }

    @Test
    func aThrowingThenStillWritesBack() async {
        let mock = MockCounter()
        stub(mock) { stub in
            when(stub.adjust(any(), by: any())).then { value, _ in
                value = 0
                throw TestError.failed
            }
        }

        var value = 5
        await #expect(throws: TestError.self) {
            try await mock.adjust(&value, by: 1)
        }
        #expect(value == 0)
    }

    @Test
    func otherStubsLeaveTheArgumentAlone() {
        let mock = MockCounter()
        stub(mock) { stub in
            when(stub.rename(any(), suffix: any())).thenReturn(7)
        }

        var name = "Ada"
        let length = mock.rename(&name, suffix: "!")

        #expect(name == "Ada")
        #expect(length == 7)
    }

    @Test
    func actorMocksWriteBack() async {
        let mock = MockInoutCounterStore()
        stub(mock) { stub in
            when(stub.bump(any(), by: any())).then { _, value, delta in value += delta }
        }

        let value = await mock.bumped(10, by: 5)

        #expect(value == 15)
        verify(mock).bump(10, by: 5)
    }

    @Test
    func classMocksWriteBackAndCallTheRealImplementation() {
        let mock = MockCounterClass()
        stub(mock) { stub in
            when(stub.double(equal(to: 1))).then { value in value = 100 }
            when(stub.double(equal(to: 2))).thenCallRealImplementation()
        }

        var first = 1
        mock.double(&first)
        var second = 2
        mock.double(&second)

        #expect(first == 100)
        #expect(second == 4)
    }
}

// An actor's `inout` argument has to be a variable isolated to the actor.
private extension InoutCounterStore {
    func bumped(_ value: Int, by delta: Int) -> Int {
        var value = value
        bump(&value, by: delta)
        return value
    }
}
