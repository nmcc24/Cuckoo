import Cuckoo

// A sync and an async overload of the same signature. Their stubbing members differ only in the stub they return,
// and their verification members in nothing, so the proxies name the sync one as usual, `stub.value()` and
// `verify(mock).value()`, and the async one through their `async` member: `stub.async.value()`,
// `verify(mock).async.value()`. Both work in synchronous code, `inOrder`'s block included, and in async code.
protocol Loading {
    func value() -> Int
    func value() async -> Int
    func load(_ id: Int) throws -> String
    func load(_ id: Int) async throws -> String
    // Without a sync overload, an async member's are plain.
    func refresh() async
    #if DEBUG
    func debug() -> Int
    func debug() async -> Int
    #endif
}

// Next to an associated type and a generic parameter.
protocol GenericLoading {
    associatedtype Item
    func item() -> Item
    func item() async -> Item
    func convert<T>(_ value: T) -> Item
    func convert<T>(_ value: T) async -> Item
}

// The overloads are a pair whatever they return, however their matchers differ and whatever their access: a call
// of the proxy's member states none of those.
protocol ResultLoading {
    func value() -> Int
    func value() async -> String
}

class IsolationLoader {
    init() {}
    func value() -> Int { 0 }
    @MainActor func value() async -> Int { 0 }
}

public class AccessLoader {
    public init() {}
    public func first() -> Int { 0 }
    func first() async -> Int { 0 }
    func second() -> Int { 0 }
    public func second() async -> Int { 0 }
}

// A member named `async` takes the name: the async overload's own members are then `async`, named with `await`.
protocol AsyncNamed {
    func async() -> Int
    func value() -> Int
    func value() async -> Int
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

// A public mock's proxies aren't `Sendable`, as an internal one's are implicitly.
public protocol PublicLoading {
    func value() -> Int
    func value() async -> Int
    static func shared() -> Int
    static func shared() async -> Int
}

func useOverloads() {
    let mock = MockLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn(2)
        when(stub.load(1)).thenReturn("sync")
        when(stub.async.load(1)).thenReturn("async")
        when(stub.refresh()).thenDoNothing()
        #if DEBUG
        when(stub.debug()).thenReturn(3)
        when(stub.async.debug()).thenReturn(4)
        #endif
    }
    verify(mock, never()).value()
    verify(mock, never()).async.value()
    inOrder {
        verify(mock, never()).value()
        verify(mock, never()).async.value()
        verify(mock, never()).async.load(any())
        verify(mock, never()).refresh()
    }

    let loader = MockLoader()
    stub(loader) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn(2)
    }
    verify(loader, never()).async.value()

    let shared = MockSharedLoading()
    stub(shared) { stub in
        when(stub.load(1)).thenReturn("sync")
        when(stub.async.load(1)).thenReturn("async")
    }
    verify(shared, never()).async.load(1)

    let generic = MockGenericLoading<Int>()
    stub(generic) { stub in
        when(stub.item()).thenReturn(1)
        when(stub.async.item()).thenReturn(1)
        when(stub.async.convert(any(String.self))).thenReturn(2)
    }
    verify(generic, never()).async.convert(any(String.self))
}

func useUnlikeOverloads() {
    let result = MockResultLoading()
    stub(result) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn("async")
    }
    verify(result, never()).value()
    verify(result, never()).async.value()

    let access = MockAccessLoader()
    stub(access) { stub in
        when(stub.first()).thenReturn(1)
        when(stub.async.first()).thenReturn(2)
        when(stub.second()).thenReturn(1)
        when(stub.async.second()).thenReturn(2)
    }
    inOrder {
        verify(access, never()).async.first()
        verify(access, never()).async.second()
    }
}

@MainActor
func useIsolationOverloads() async {
    let mock = MockIsolationLoader()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn(2)
    }
    _ = await mock.value()
    verify(mock, never()).value()
    verify(mock).async.value()
}

// In async code the proxies' members mean the same: no `await`, and the sync overload without a closure around it.
func useOverloadsInAsyncCode() async throws {
    let mock = MockLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn(2)
        when(stub.async.load(1)).thenReturn("async")
    }
    _ = await mock.value()
    _ = try await mock.load(1)
    verify(mock, never()).value()
    verify(mock).async.value()
    verify(mock).async.load(1)

    let named = MockAsyncNamed()
    stub(named) { stub in
        when(stub.async()).thenReturn(1)
        when(stub.value()).thenReturn(1)
    }
    when(await named.cuckooStubbingProxy().value()).thenReturn(2)
    await verify(named, never()).value()
}

@MainActor
func useMainOverloads() async {
    let mock = MockMainLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn(2)
    }
    _ = await mock.value()
    verify(mock, never()).value()
    inOrder {
        verify(mock).async.value()
    }
}

@MainActor
func usePublicOverloads() async {
    let mock = MockPublicLoading()
    stub(mock) { stub in
        when(stub.value()).thenReturn(1)
        when(stub.async.value()).thenReturn(2)
    }
    stub(MockPublicLoading.self) { stub in
        when(stub.shared()).thenReturn(1)
        when(stub.async.shared()).thenReturn(2)
    }
    _ = await MockPublicLoading.shared()
    verify(MockPublicLoading.self, never()).shared()
    inOrder {
        verify(mock, never()).async.value()
        verify(MockPublicLoading.self).async.shared()
    }
}
