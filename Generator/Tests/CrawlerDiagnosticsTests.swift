import Foundation
import Testing
@testable import CuckooGenerator

// On Darwin, Foundation also exports the Objective-C runtime's `Method`, so name the generator's explicitly.
private typealias MethodToken = CuckooGenerator.Method

/// Input the generator can't fully handle produces a warning and is skipped, instead of crashing the generator.
struct CrawlerDiagnosticsTests {
    private let url = URL(filePath: "/project/Sources/Service.swift")

    /// A mock can't return a `~Escapable` value: a class's member keeps the real implementation, and a protocol with
    /// one isn't mocked, with a warning either way.
    @Test
    func nonescapableResultsAreSkippedWithAWarning() throws {
        let crawler = Crawler.crawl(source: """
            class Buffer {
                func bytes() -> Span<UInt8> { fatalError() }
                func count() -> Int { 0 }
            }

            protocol ByteSource {
                var bytes: Swift.RawSpan? { get }
            }
            """, url: url)

        let buffer = try #require(crawler.tokens.first as? ClassDeclaration)
        #expect(buffer.members.compactMap { ($0 as? MethodToken)?.name } == ["count"])
        #expect(crawler.tokens.count == 1)
        #expect(crawler.diagnostics.map(\.description) == [
            "/project/Sources/Service.swift:2:5: warning: cuckoo: 'bytes()' returns the ~Escapable type 'Span<UInt8>', which a mock can't return. The mock keeps the real implementation.",
            "/project/Sources/Service.swift:6:1: warning: cuckoo: 'ByteSource' isn't mocked: 'bytes' returns the ~Escapable type 'Swift.RawSpan?', which a mock can't return.",
        ])
    }

    /// A class whose initializers are all private is mocked with a warning: no test can create its mock. One with
    /// an accessible initializer gets none.
    @Test
    func aClassWithOnlyPrivateInitializersWarns() throws {
        let crawler = Crawler.crawl(source: """
            class Singleton {
                static let shared: Singleton = Singleton()
                private init() {}
                func load() {}
            }

            class Service {
                private init(secret: Int) {}
                init() {}
            }
            """, url: url)

        #expect(crawler.tokens.count == 2)
        #expect(crawler.diagnostics.map(\.description) == [
            "/project/Sources/Service.swift:1:1: warning: cuckoo: 'Singleton' is mocked, but its initializers are private, so no test can create its mock.",
        ])
    }

    /// A protocol refining one that isn't mocked isn't mocked either, as its mock would need the same requirement.
    @Test
    func protocolsRefiningAnUnmockedOneAreSkippedWithAWarning() async throws {
        var mocks = ""
        let printed = try await capturingOutput {
            mocks = try await generateMocks(source: """
                struct Receipt: ~Copyable {}
                protocol Printer {
                    func receipt() -> Receipt
                }
                protocol FancyPrinter: Printer {}
                protocol LabelPrinter: FancyPrinter {}
                protocol Scanner {
                    func scan()
                }
                """)
        }
        #expect(printed.contains("'FancyPrinter' isn't mocked: it refines 'Printer', which isn't mocked."))
        #expect(printed.contains("'LabelPrinter' isn't mocked: it refines 'FancyPrinter', which isn't mocked."))
        #expect(!mocks.contains("Printer"))
        #expect(mocks.contains("class MockScanner"))
    }

    @Test
    func propertyWithoutInferableTypeIsSkippedWithAWarning() throws {
        let crawler = Crawler.crawl(source: """
            class Service {
                var name: String = ""
                var retries = Retries(3)
                var connection = makeConnection()
                var pending = [makeConnection()]
            }
            """, url: url)

        let service = try #require(crawler.tokens.first as? ClassDeclaration)
        #expect(service.members.compactMap { ($0 as? Variable)?.name } == ["name"])
        #expect(crawler.diagnostics.map(\.description) == [
            "/project/Sources/Service.swift:3:9: warning: cuckoo: Can't infer the type of property 'retries', so it isn't mocked. Add a type annotation to mock it.",
            "/project/Sources/Service.swift:4:9: warning: cuckoo: Can't infer the type of property 'connection', so it isn't mocked. Add a type annotation to mock it.",
            "/project/Sources/Service.swift:5:9: warning: cuckoo: Can't infer the type of property 'pending', so it isn't mocked. Add a type annotation to mock it.",
        ])
    }

    /// `var x, y: Int` used to crash the generator: `x` has neither a type annotation nor an initializer.
    @Test
    func bindingsShareTheNextTypeAnnotation() throws {
        let crawler = Crawler.crawl(source: """
            class Point {
                var x, y: Int
                var label = "", z: Double
            }
            """, url: url)

        let point = try #require(crawler.tokens.first as? ClassDeclaration)
        let variables = point.members.compactMap { $0 as? Variable }.map { "\($0.name): \($0.type)" }
        #expect(variables == ["x: Int", "y: Int", "label: String", "z: Double"])
        #expect(crawler.diagnostics.isEmpty)
    }

    @Test
    func bareArrayAndDictionaryTypesAreKeptAsWritten() throws {
        let crawler = Crawler.crawl(source: """
            protocol Store {
                func all() -> Array
                func index() -> Dictionary
            }
            """, url: url)

        let store = try #require(crawler.tokens.first as? ProtocolDeclaration)
        let returnTypes = store.members.compactMap { ($0 as? MethodToken)?.returnType?.description }
        #expect(returnTypes == ["Array", "Dictionary"])
        #expect(crawler.diagnostics.isEmpty)
    }

    /// A property is settable with a writing accessor or observers, and read-only with reading accessors only.
    @Test
    func propertiesAreReadOnlyWithOnlyReadingAccessors() throws {
        let crawler = Crawler.crawl(source: """
            class Store {
                var a: Int { _read { yield 0 } }
                var b: Int { unsafeAddress { fatalError() } }
                var c: Int { get { 0 } _modify { fatalError() } }
                var e: Int { unsafeAddress { fatalError() } mutableAddressWithOwner { fatalError() } }
                var f: Int { unsafeAddress { fatalError() } mutableAddressWithNativeOwner { fatalError() } }
                var g = 0 { didSet {} }
            }
            """, url: url)
        let store = try #require(crawler.tokens.first as? ClassDeclaration)
        let readOnly = store.members.compactMap { $0 as? Variable }.map { "\($0.name): \($0.isReadOnly)" }
        #expect(readOnly == ["a: true", "b: true", "c: false", "e: false", "f: false", "g: false"])
    }

    #if canImport(SwiftSyntax604)
    /// `mutate` is a writing accessor. swift-syntax parses it from 604, the release of the first Swift that has it.
    @Test
    func mutateAccessorIsWriting() throws {
        let crawler = Crawler.crawl(source: """
            class Store {
                var d: Int { get { 0 } mutate { fatalError() } }
            }
            """, url: url)
        let store = try #require(crawler.tokens.first as? ClassDeclaration)
        #expect(store.members.compactMap { $0 as? Variable }.map(\.isReadOnly) == [false])
    }
    #endif
}

/// Invalid or unusual source the generator reads without crashing, and declarations it leaves alone.
struct InvalidSourceTests {
    /// Swift rejects a type that inherits from itself, and a protocol without a name; the generator still finishes,
    /// so the compiler's own error is what the build reports.
    @Test(arguments: [
        "class A: A { init() {}; func a() {} }",
        "protocol X: Y { func x() }\nprotocol Y: X { func y() }",
        "protocol P { func p() }\nprotocol : P { func q() }",
    ])
    func invalidInheritanceDoesNotCrash(source: String) async throws {
        _ = try await capturingOutput {
            _ = try await generateMocks(source: source)
        }
    }

    /// A type declared in a macro's closure, such as `#Preview`'s, is local to it.
    @Test
    func typesInAMacroClosureAreNotMocked() async throws {
        let mocks = try await generateMocks(source: """
            protocol Service {
                func load() -> Int
            }
            #Preview {
                class FakeService: Service { func load() -> Int { 1 } }
                return FakeService()
            }
            """)
        #expect(mocks.contains("class MockService"))
        #expect(!mocks.contains("FakeService"))
    }
}
