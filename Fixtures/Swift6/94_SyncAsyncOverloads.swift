import Cuckoo

// A sync and an async overload of the same signature. Their stubbing members differ only in the stub they return,
// and their verification members in nothing, so the async one's are `async`: a call picks one as Swift picks a
// call's overload, the sync one in a synchronous context and the async one with `await`.
protocol Loading {
    func value() -> Int
    func value() async -> Int
    func load(_ id: Int) throws -> String
    func load(_ id: Int) async throws -> String
    // Without a sync overload, an async member's are plain.
    func refresh() async
}

class Loader {
    init() {}
    func value() -> Int { 0 }
    func value() async -> Int { 0 }
}

@MainActor
protocol MainLoading {
    func value() -> Int
    func value() async -> Int
}

protocol SharedLoading: Sendable {
    func load(_ id: Int) -> String
    func load(_ id: Int) async -> String
}

// A public mock's proxies aren't `Sendable`, as an internal one's are implicitly: the async members run on their
// caller's actor, so a caller on the main actor keeps the proxy there.
public protocol PublicLoading {
    func value() -> Int
    func value() async -> Int
    static func shared() -> Int
    static func shared() async -> Int
}

func useOverloads() async throws {
    let mock = MockLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.load(1)).thenReturn("sync")
        when(stub.refresh()).thenDoNothing()
    }
    let stubbing = mock.cuckooStubbingProxy()
    when(await stubbing.value()).thenReturn(2)
    when(await stubbing.load(1)).thenReturn("async")

    _ = await mock.value()
    _ = try await mock.load(1)
    await verify(mock).value()
    await verify(mock).load(1)
    inOrder {
        verify(mock, never()).value()
    }

    let loader = MockLoader()
    stub(loader) { stub in
        when(stub.value()).thenReturn(1)
    }
    when(await loader.cuckooStubbingProxy().value()).thenReturn(2)

    let shared = MockSharedLoading()
    stub(shared) { stub in
        when(stub.load(1)).thenReturn("sync")
    }
    when(await shared.cuckooStubbingProxy().load(1)).thenReturn("async")
}

@MainActor
func useMainOverloads() async {
    let mock = MockMainLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
    }
    when(await mock.cuckooStubbingProxy().value()).thenReturn(2)
    await verify(mock, never()).value()
}

@MainActor
func usePublicOverloads() async {
    let mock = MockPublicLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
    }
    when(await mock.cuckooStubbingProxy().value()).thenReturn(2)
    await verify(mock, never()).value()

    // Static members' proxies take `await` the same way; the async one's stubbing proxy is made from the manager.
    stub(MockPublicLoading.self) { stub in
        when(stub.shared()).thenReturn(1)
    }
    let staticStubbing = MockPublicLoading.CuckooStaticStubbing(manager: MockPublicLoading.cuckooStaticManager)
    when(await staticStubbing.shared()).thenReturn(2)
    _ = await MockPublicLoading.shared()
    await verify(MockPublicLoading.self).shared()
}
