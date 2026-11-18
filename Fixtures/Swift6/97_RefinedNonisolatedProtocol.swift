import Cuckoo

// A protocol refining a `nonisolated` one. With `-default-isolation MainActor` the refining protocol takes the
// default itself, so its own requirements are main-actor isolated; the ones it inherits stay nonisolated. A
// `nonisolated` class conforming to it gets the same split from its witnesses, and so do the mocks of both.
nonisolated class Unbound {
    init() {}
}

nonisolated protocol Anywhere {
    func anywhere() -> Int
}

protocol Refining: Anywhere {
    func refined() -> Int
}

protocol RefiningAgain: Refining {
    func again() -> Int
}

// Stated, `nonisolated` covers the refining protocol's own requirements too.
nonisolated protocol StatedRefining: Anywhere {
    func stated() -> Int
}

class Refined: Unbound, RefiningAgain, StatedRefining {
    func anywhere() -> Int { 0 }
    func refined() -> Int { 0 }
    func again() -> Int { 0 }
    func stated() -> Int { 0 }
}

// Nonisolated in every mode.
nonisolated func callAnywhere(_ refined: MockRefined, _ again: MockRefiningAgain, _ stated: MockStatedRefining) -> Int {
    refined.anywhere() + refined.stated() + again.anywhere() + stated.anywhere() + stated.stated()
}

@MainActor
func callRefined(_ refined: MockRefined, _ again: MockRefiningAgain) -> Int {
    stub(again) { stub in
        when(stub.refined()).thenReturn(1)
        when(stub.again()).thenReturn(2)
    }
    return refined.refined() + refined.again() + again.refined() + again.again()
}
