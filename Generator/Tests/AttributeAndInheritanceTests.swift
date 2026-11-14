import Foundation
import Testing
@testable import CuckooGenerator

/// Attributes the generator doesn't know, global actors from other modules, and parents it resolves by scope.
@Suite
struct AttributeAndInheritanceTests {
    private let url = URL(filePath: "/project/Sources/Store.swift")

    /// An unknown attribute named like a global actor is likely one from another module: a warning says how to
    /// declare it. Any other unknown attribute only gets a comment in the mock.
    @Test
    func unknownActorAttributeWarns() throws {
        let crawler = Crawler.crawl(source: """
            @DatabaseActor
            protocol Store {
                func load() -> Int
            }

            @Tracked
            protocol Logger {
                func log()
            }
            """, url: url)

        #expect(crawler.diagnostics.map(\.description) == [
            "/project/Sources/Store.swift:1:1: warning: cuckoo: 'Store' is marked @DatabaseActor, which isn't a global actor declared in the mocked sources, so its mock isn't isolated to it. If @DatabaseActor is a global actor from another module, add it to the module's `globalActors` in the Cuckoofile.",
        ])
    }

    @Test
    func unknownAttributeIsNotedInTheMock() async throws {
        let output = try await generateMocks(source: """
            @Tracked
            protocol Logger {
                func log()
            }
            """)
        #expect(output.contains("@Tracked"))
        #expect(output.contains("final class MockLogger: Logger,"))
        #expect(!output.contains("@Tracked\nfinal class MockLogger"))
    }

    /// A global actor listed in the Cuckoofile isolates the mock, as one declared in the sources does.
    @Test
    func globalActorsFromTheCuckoofileIsolateTheMock() async throws {
        let source = """
            @DatabaseActor
            protocol Store {
                func load() -> Int
            }
            """
        let isolatedStub = "Cuckoo.ProtocolStubFunction<(), Int, @DatabaseActor @Sendable (()) -> Int, Cuckoo.StubSharing.Isolated>"
        #expect(try await generateMocks(source: source, moduleKeys: #"globalActors = ["DatabaseActor"]"#).contains(isolatedStub))
        #expect(try await !generateMocks(source: source).contains(isolatedStub))
    }

    /// A parent only protocols nested in unrelated scopes are named like is one from outside the sources, as it is
    /// to Swift: `Error` is Swift's, not `Net.Error`, and two nested `CustomStringConvertible`s don't make
    /// `Other`'s parent ambiguous.
    @Test
    func nestedProtocolsDontStandInForOutsideParents() async throws {
        let output = try await generateMocks(source: """
            enum Net { protocol Error { func netOnly() } }
            protocol Plain: Error { func work() }
            enum A { protocol CustomStringConvertible { func a() } }
            enum B { protocol CustomStringConvertible { func b() } }
            protocol Other: CustomStringConvertible { func other() }
            """)
        let plain = try #require(output.range(of: "class MockPlain"))
        #expect(!output[plain.lowerBound...].prefix(2000).contains("netOnly"))
        let other = try #require(output.range(of: "class MockOther"))
        let otherMock = output[other.lowerBound...].prefix(3000)
        #expect(!otherMock.contains("func a()") && !otherMock.contains("func b()"))
        #expect(output.contains("// Other inherits 'CustomStringConvertible', declared outside the mocked sources"))
    }

    /// A parent named through a typealias, or from an extension that names its type with the module or through a
    /// typealias, is found as Swift finds it.
    @Test
    func parentsResolveThroughTypealiasesAndQualifiedExtensions() async throws {
        let output = try await generateMocks(source: """
            enum Feature { protocol Service { func service() } }
            typealias Service = Feature.Service
            protocol ThroughAlias: Service { func own() }
            enum Outer { protocol Base { func base() } }
            typealias O = Outer
            extension App.Outer { protocol Qualified: Base { func qualified() } }
            extension O { protocol Aliased: Base { func aliased() } }
            """)
        let alias = try #require(output.range(of: "class MockThroughAlias"))
        #expect(output[alias.lowerBound...].prefix(3000).contains("func service()"))
        let qualified = try #require(output.range(of: "class MockQualified"))
        #expect(output[qualified.lowerBound...].prefix(3000).contains("func base()"))
        let aliased = try #require(output.range(of: "class MockAliased"))
        #expect(output[aliased.lowerBound...].prefix(3000).contains("func base()"))
    }

    /// A parent reached through an enclosing scope, or through a composition typealias, gives its requirements.
    @Test
    func parentsResolveThroughScopesAndCompositions() async throws {
        let output = try await generateMocks(source: """
            enum Feature {
                protocol Service { func one() }
                protocol Child: Service { func child() }
            }
            protocol PartA { func a() }
            protocol PartB { func b() }
            typealias PartAB = PartA & PartB
            protocol Composed: PartAB { func composed() }
            """)
        let child = try #require(output.range(of: "class MockChild"))
        #expect(output[child.lowerBound...].contains("func one()"))
        let composed = try #require(output.range(of: "class MockComposed"))
        #expect(output[composed.lowerBound...].contains("func a()"))
        #expect(output[composed.lowerBound...].contains("func b()"))
    }

    /// A public class whose non-public members name a non-public type gets an internal mock, which says why. A name
    /// that's also a public type's, such as a nested internal `Config` next to a public one, doesn't count.
    @Test
    func internalMockSaysWhy() async throws {
        let output = try await generateMocks(source: """
            struct Hidden {}
            public struct Config { public init() {} }
            struct Settings { struct Config {} }
            public class Client {
                public init() {}
                func configure(_ config: Config) {}
            }
            public class Store {
                public init() {}
                func keep(_ hidden: Hidden) {}
            }
            """)
        #expect(output.contains("public final class MockClient: Client,"))
        #expect(output.contains("\nfinal class MockStore: Store,"))
        #expect(output.contains("// This mock is internal: Store's non-public members name the non-public type 'Hidden',"))
    }
}
