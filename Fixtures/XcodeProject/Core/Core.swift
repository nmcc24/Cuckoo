protocol Clock {
    func now() -> Int
}

struct Stopwatch {
    let clock: any Clock

    func elapsed(since start: Int) -> Int {
        clock.now() - start
    }
}
