// Types that only look `~Escapable` or `~Copyable`: the module's own `Span`, a `~Copyable` generic type that an
// extension makes `Copyable` for copyable arguments, and a top-level `Token` next to a nested `~Copyable` one.
final class Span {}

protocol Tracer {
    func startSpan(_ name: String) -> Span
}

struct Box<T: ~Copyable>: ~Copyable {
    var value: T
}

extension Box: Copyable where T: Copyable {}

protocol BoxMaker {
    func make() -> Box<Int>
    func take(_ box: Box<Int>)
}

enum Outer {
    struct Token: ~Copyable {
        var id: Int
    }
}

struct Token {
    var id: Int
}

protocol Tokens {
    func token() -> Token
    func use(_ token: Token) -> Int
}
