import Testing
@testable import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Stubbing and verifying static and class members. Each test gets its own registry from the `.cuckoo()` trait.
@Suite(.cuckoo())
struct StaticMemberTests {
    private enum TestError: Error {
        case failed
    }

    @Test
    func staticMethodsAndProperties() async throws {
        stub(MockStaticFactory.self) { stub in
            when(stub.make()).then { MockStaticFactory() }
            when(stub.count.get).thenReturn(3)
            when(stub.count.set(anyInt())).thenDoNothing()
            when(stub.name.get).thenReturn("factory")
            when(stub["a"].get).thenReturn(1)
            when(stub.load(id: 1)).thenReturn("one")
            when(stub.load(id: 2)).thenThrow(TestError.failed)
        }

        _ = MockStaticFactory.make()
        MockStaticFactory.count = 4
        #expect(MockStaticFactory.count == 3)
        #expect(MockStaticFactory.name == "factory")
        #expect(MockStaticFactory["a"] == 1)
        #expect(try await MockStaticFactory.load(id: 1) == "one")
        await #expect(throws: TestError.self) { try await MockStaticFactory.load(id: 2) }

        verify(MockStaticFactory.self).make()
        verify(MockStaticFactory.self).count.set(4)
        verify(MockStaticFactory.self).count.get()
        verify(MockStaticFactory.self)["a"].get()
        verify(MockStaticFactory.self, times(2)).load(id: anyInt())
    }

    @Test
    func staticStubsDontReachInstances() {
        let mock = MockStaticFactory()
        stub(MockStaticFactory.self) { stub in
            when(stub.name.get).thenReturn("static")
        }
        stub(mock) { stub in
            when(stub.build()).thenReturn(5)
        }

        #expect(mock.build() == 5)
        #expect(MockStaticFactory.name == "static")
        verify(mock).build()
        verifyNoMoreInteractions(mock)
        verify(MockStaticFactory.self).name.get()
        verifyNoMoreInteractions(MockStaticFactory.self)
    }

    @Test
    func classMembersCallTheRealImplementation() {
        stub(MockStaticMembersClass.self) { stub in
            when(stub.version.get).thenReturn(7)
            when(stub.describe(1)).thenReturn("stubbed")
            when(stub.describe(2)).thenCallRealImplementation()
        }

        #expect(MockStaticMembersClass.version == 7)
        #expect(MockStaticMembersClass.describe(1) == "stubbed")
        #expect(MockStaticMembersClass.describe(2) == "real 2")
        #expect(MockStaticMembersClass.notMocked() == 0)
        verify(MockStaticMembersClass.self, times(2)).describe(anyInt())
    }

    @Test
    func genericProtocolStaticMember() {
        stub(MockGenericStaticFactory<Int>.self) { stub in
            when(stub.make()).thenReturn(42)
        }

        #expect(MockGenericStaticFactory<Int>.make() == 42)
        verify(MockGenericStaticFactory<Int>.self).make()
    }

    @Test
    func resetClearsStaticStubsAndCalls() {
        stub(MockStaticFactory.self) { stub in
            when(stub.name.get).thenReturn("before")
        }
        _ = MockStaticFactory.name

        reset(MockStaticFactory.self)

        verify(MockStaticFactory.self, never()).name.get()
    }

    /// Cases run in parallel; each sees only its own stubs and calls.
    @Test(arguments: 0..<20)
    func parallelTestsDontShareStaticStubs(value: Int) async {
        stub(MockStaticFactory.self) { stub in
            when(stub.count.get).thenReturn(value)
        }
        await Task.yield()

        #expect(MockStaticFactory.count == value)
        verify(MockStaticFactory.self).count.get()
    }

    @Test
    func childTasksSeeTheTestsStubs() async {
        stub(MockStaticFactory.self) { stub in
            when(stub.count.get).thenReturn(9)
        }

        let value = await Task { MockStaticFactory.count }.value

        #expect(value == 9)
    }

    @Test
    func withStaticStubsStartsAFreshScope() async {
        stub(MockStaticFactory.self) { stub in
            when(stub.count.get).thenReturn(1)
        }

        withStaticStubs {
            stub(MockStaticFactory.self) { stub in
                when(stub.count.get).thenReturn(2)
            }
            #expect(MockStaticFactory.count == 2)
        }
        await withStaticStubs {
            stub(MockStaticFactory.self) { stub in
                when(stub.count.get).thenReturn(3)
            }
            await Task.yield()
            #expect(MockStaticFactory.count == 3)
            verify(MockStaticFactory.self).count.get()
        }

        #expect(MockStaticFactory.count == 1)
        verify(MockStaticFactory.self).count.get()
    }

    @Test
    func usingStaticMembersOutsideAScopeFails() {
        let failures = Locked<[String]>([])
        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: { message, _ in failures.withLock { $0.append(message) } })) {
            StaticStubs.$current.withValue(nil) {
                _ = MockStaticFactory.count
            }
        }

        #expect(failures.withLock { $0 }.contains { $0.contains("outside a static stubs scope") })
    }

    @Test
    func staticMembersRefuseADefaultImplementation() {
        let failures = Locked<[String]>([])
        CuckooConfiguration.$current.withValue(CuckooConfiguration(failureHandler: { message, _ in failures.withLock { $0.append(message) } })) {
            MockStaticFactory.cuckoo_staticManager.enableDefaultStubImplementation()
        }
        stub(MockStaticFactory.self) { stub in
            when(stub.count.get).thenReturn(3)
        }

        #expect(failures.withLock { $0 } == ["Static members have no default implementation. Stub them instead."])
        #expect(MockStaticFactory.count == 3)
    }
}

