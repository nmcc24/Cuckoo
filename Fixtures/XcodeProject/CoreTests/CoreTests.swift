import Cuckoo
import Testing
@testable import Core

@Test(.cuckoo())
func stopwatchMeasuresFromTheClock() {
    let clock = MockClock()
    stub(clock) { stub in
        when(stub.now()).thenReturn(15)
    }

    #expect(Stopwatch(clock: clock).elapsed(since: 10) == 5)
    verify(clock).now()
}
