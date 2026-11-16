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
        #expect(service.members.compactMap { ($0 as? Variable)?.name } == ["name", "retries"])
        #expect(crawler.diagnostics.map(\.description) == [
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
}
