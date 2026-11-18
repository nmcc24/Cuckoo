import Cuckoo

// Must not compile: a Sendable mock's stubs can be matched from any task, so they reject a matcher that keeps a
// non-Sendable value. Listed in the expected failures. The failing code sits under `CUCKOO_MUST_FAIL`, so the matrix
// first compiles the fixture and its mock without it, region-isolation checks included.
nonisolated final class Token: Equatable {
    static func == (lhs: Token, rhs: Token) -> Bool { lhs === rhs }
}

nonisolated protocol TokenCache: Sendable {
    func store(_ token: Token)
}

#if CUCKOO_MUST_FAIL
func stubTokens(cache: MockTokenCache) {
    let token = Token()
    stub(cache) { stub in
        when(stub.store(equal(to: token))).thenDoNothing()
    }
}
#endif
