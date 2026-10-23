import Foundation
import Testing
#if canImport(CuckooGenerator)
// SwiftPM tests the executable target; the Tuist test target compiles the generator sources in directly.
@testable import CuckooGenerator
#endif

/// Input the generator can't fully handle produces a warning and is skipped, instead of crashing the generator.
struct CrawlerDiagnosticsTests {
    private let url = URL(fileURLWithPath: "/project/Sources/Service.swift")

    @Test
    func propertyWithoutInferableTypeIsSkippedWithAWarning() throws {
        let crawler = Crawler.crawl(source: """
            class Service {
                var name: String = ""
                var retries = Retries(3)
                var connection = makeConnection()
                var pending = [1, 2]
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
        let returnTypes = store.members.compactMap { ($0 as? Method)?.returnType?.description }
        #expect(returnTypes == ["Array", "Dictionary"])
        #expect(crawler.diagnostics.isEmpty)
    }
}
