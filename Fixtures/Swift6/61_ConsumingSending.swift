// A parameter both `consuming` and `sending`: the mock forwards the value its wrapper holds, which `copy` can't take.
final class Payload {}

class Uploader {
    init() {}
    func upload(_ payload: consuming sending Payload) async -> Int { 0 }
}

protocol Sink {
    func put(_ payload: consuming sending Payload)
}

// In an actor mock, the `then` closure gets the argument from the manager instead of capturing it.
protocol SinkActor: Actor {
    func put(_ payload: consuming sending Payload)
}
