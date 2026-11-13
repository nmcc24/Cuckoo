import Cuckoo

// Stubbing with matchers, compiled in every mode. With the Xcode 26 defaults (-default-isolation MainActor),
// `Profile`'s `==` is isolated to the main actor, so `equal(to: profile)` must take the non-Sendable matcher, which a
// mock that isn't Sendable accepts.
struct Profile: Equatable {
    var name: String
}

final class Session {
    var token = "t"
}

protocol ProfileStore {
    func save(_ profile: Profile, tags: [String]) -> Bool
    func open(_ session: Session)
}

// A Sendable mock: its stubs only take Sendable matchers.
nonisolated protocol ProfileCache: Sendable {
    func lookup(_ name: String, limit: Int?) -> Int
    func names(matching tags: [String]) -> [String]
}

func stubProfiles(store: MockProfileStore, cache: MockProfileCache) {
    let profile = Profile(name: "Ann")
    let session = Session()
    stub(store) { stub in
        when(stub.save(equal(to: profile), tags: containsAnyOf(values: "a", "b"))).thenReturn(true)
        // The closure captures a non-Sendable session, so it takes the non-Sendable matcher.
        when(stub.save(any(), tags: containsAllOf(values: "x", where: { $0 == $1 + session.token }))).thenReturn(false)
        when(stub.open(sameInstance(as: session))).thenDoNothing()
        when(stub.open(not(sameInstance(as: session)))).thenDoNothing()
    }
    stub(cache) { stub in
        when(stub.lookup("Ann", limit: isNil())).thenReturn(1)
        when(stub.lookup(equal(to: "Ann").or(equal(to: "Bo")), limit: 3)).thenReturn(2)
        when(stub.lookup(anyString(), limit: notNil())).thenReturn(3)
        when(stub.names(matching: containsAnyOf(values: "a", where: { $0 == $1 }))).thenReturn([])
        when(stub.names(matching: hasLength(atLeast: 2))).thenReturn(["a"])
    }
}
