import Cuckoo

// Must not compile: a Sendable mock's stubs can be matched from any task, so they reject a matcher that keeps a
// non-Sendable value. Listed in the expected failures.
nonisolated final class Token: Equatable {
    static func == (lhs: Token, rhs: Token) -> Bool { lhs === rhs }
}

nonisolated protocol TokenCache: Sendable {
    func store(_ token: Token)
}

func stubTokens(cache: MockTokenCache) {
    let token = Token()
    stub(cache) { stub in
        when(stub.store(equal(to: token))).thenDoNothing()
    }
}
