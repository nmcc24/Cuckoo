// What the mocks can't take from a parent, each with a warning.
struct Ticket: ~Copyable {}

// An unmocked protocol is known by its qualified name: `First.Issuer` isn't mocked, `Second.Issuer` is.
enum First {
    protocol Issuer {
        func issue() -> Ticket
    }
}

enum Second {
    protocol Issuer {
        func count() -> Int
    }
}

protocol Counting: Second.Issuer {
    func reset()
}

// A generic superclass's members aren't overridden by a subclass's mock.
class Container<T> {
    init() {}
    func take(_ value: T) {}
    func plain() {}
}

class IntContainer: Container<Int> {
    func own() {}
}

// A capitalized function's call initializes nothing, so the property's type isn't guessed from it.
enum Kind {
    case a
    static func Make() -> Kind { .a }
}

func Factory() -> Int { 1 }

class Guessing {
    init() {}
    var kind = Kind.Make()
    var made = Factory()
    var count = 1
}
