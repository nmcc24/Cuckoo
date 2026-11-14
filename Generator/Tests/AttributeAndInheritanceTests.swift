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

    /// A parent named the same as protocols in two scopes, neither of them the inheriting type's, is an error that
    /// names both, rather than a guess.
    @Test
    func ambiguousParentIsAnError() async throws {
        let error = await #expect(throws: AmbiguousInheritanceError.self) {
            try await generateMocks(source: """
                enum FeatureOne {
                    protocol Service { func one() }
                }
                enum FeatureTwo {
                    protocol Service { func two() }
                }
                protocol Child: Service { func child() }
                """)
        }
        #expect(error?.candidates.sorted() == ["FeatureOne.Service", "FeatureTwo.Service"])
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
}
