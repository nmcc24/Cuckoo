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
    /// that's also a public type's, such as a nested internal `Config` next to a public one, may be either, so it
    /// counts too: an internal mock compiles in both cases.
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
        #expect(output.contains("\nfinal class MockClient: Client,"))
        #expect(output.contains("// This mock is internal: Client's non-public members name 'Config', which the module declares"))
        #expect(output.contains("\nfinal class MockStore: Store,"))
        #expect(output.contains("// This mock is internal: Store's non-public members name 'Hidden', which the module declares"))
    }

    /// A generic parameter or associated type named like one of the mock's own type names, such as `Stubbing`, would
    /// make a mock that can't compile, so the type is left out with a warning that says what to rename.
    @Test
    func reservedGenericNameSkipsTheMockWithAWarning() throws {
        let crawler = Crawler.crawl(source: """
            protocol Pipeline {
                associatedtype Stubbing
                func run(_ stubbing: Stubbing)
            }
            class Box<Verification> {
                init() {}
            }
            """, url: url)
        #expect(crawler.tokens.isEmpty)
        #expect(crawler.diagnostics.map(\.description) == [
            "/project/Sources/Store.swift:1:1: warning: cuckoo: 'Pipeline' has a generic parameter or associated type named 'Stubbing', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Pipeline'.",
            "/project/Sources/Store.swift:5:1: warning: cuckoo: 'Box' has a generic parameter or associated type named 'Verification', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Box'.",
        ])
    }

    /// One in an extension of the type, or in a class it inherits from, clashes too.
    @Test
    func reservedNameInAnExtensionOrSuperclassSkipsTheMock() throws {
        let source = """
            class Foo {
                init() {}
                func a(_ s: Stubbing) -> Int { 0 }
            }
            extension Foo {
                struct Stubbing {}
            }
            class Base {
                struct Verification {}
                init() {}
            }
            class Child: Base {
                func b(_ v: Verification) -> Int { 0 }
            }
            """
        let crawler = Crawler.crawl(source: source, url: url)
        // Only the extension's token is left, which has nothing to mock.
        #expect(!crawler.tokens.contains { $0 is ClassDeclaration })
        #expect(crawler.diagnostics.map(\.message) == [
            "'Foo' has a nested type or typealias named 'Stubbing', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Foo'.",
            "'Base' has a nested type or typealias named 'Verification', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Base'.",
            "'Child' has a nested type or typealias named 'Verification', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Child'.",
        ])
    }

    /// A nested type or typealias of such a name, under `#if` too, would clash with the mock's own as well.
    @Test
    func reservedNestedNameSkipsTheMockWithAWarning() throws {
        let crawler = Crawler.crawl(source: """
            class Crate {
                struct Stubbing {}
                init() {}
                func make() -> Stubbing { Stubbing() }
            }
            protocol Shelf {
                #if DEBUG
                typealias Verification = Int
                #endif
                func count() -> Int
            }
            """, url: url)
        #expect(crawler.tokens.isEmpty)
        #expect(crawler.diagnostics.map(\.description) == [
            "/project/Sources/Store.swift:1:1: warning: cuckoo: 'Crate' has a nested type or typealias named 'Stubbing', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Crate'.",
            "/project/Sources/Store.swift:6:1: warning: cuckoo: 'Shelf' has a nested type or typealias named 'Verification', which its mock needs for itself, so it isn't mocked. Rename it to mock 'Shelf'.",
        ])
    }

    /// Two types of the same qualified name, from two files, get mocks that clash: the warning names both files. One
    /// under `#if` may be the other's alternative, so it doesn't count.
    @Test
    func duplicateDeclarationsAcrossFilesWarn() {
        func file(_ path: String, _ source: String) -> FileRepresentation {
            let url = URL(filePath: path)
            let crawler = Crawler.crawl(source: source, url: url)
            return FileRepresentation(file: TextFile(path: Path(path)), imports: [], tokens: crawler.tokens)
        }
        let warnings = Generator.duplicateDeclarationWarnings([
            file("/project/A/User.swift", "protocol User { func a() }\nenum Outer { protocol Inner {} }"),
            file("/project/B/User.swift", "protocol User { func b() }\nenum Other { protocol Inner {} }"),
            file("/project/C/User.swift", "#if os(Linux)\nprotocol User { func c() }\n#endif"),
        ])
        #expect(warnings == [
            "'User' is declared in /project/A/User.swift and in /project/B/User.swift, so their mocks have the same name and don't compile together. List only one of them in the module's `sources`.",
        ])
    }
}
