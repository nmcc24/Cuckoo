import Foundation
import Testing
@testable import CuckooGenerator

/// A stored property without a type annotation is mocked with the type its initializer names, and skipped with a
/// warning when the initializer doesn't name one.
struct TypeGuesserTests {
    @Test(arguments: [
        ("1", "Int"),
        ("-1", "Int"),
        ("0xbeef", "Int"),
        ("1_000", "Int"),
        ("1.5", "Double"),
        ("-1e3", "Double"),
        ("\"a as b\"", "String"),
        ("\"\"\"\n    text\n    \"\"\"", "String"),
        ("true", "Bool"),
        ("Retries(3)", "Retries"),
        ("Retries.init(3)", "Retries"),
        ("Outer.Inner()", "Outer.Inner"),
        ("Box<Int>()", "Box<Int>"),
        ("value as Double", "Double"),
        ("value as! [Int]", "[Int]"),
        ("value as? any Sendable", "Optional<any Sendable>"),
    ])
    func initializerNamesTheType(initializer: String, type: String) throws {
        #expect(try guessedType(of: initializer) == type)
    }

    @Test(arguments: [
        "Style.default",
        "UUID().uuidString",
        "makeConnection()",
        "Factory.make()",
        "[1, 2]",
        ".init()",
        "-value",
        "a + b",
    ])
    func initializerThatDoesNotNameATypeIsSkipped(initializer: String) throws {
        #expect(try guessedType(of: initializer) == nil)
    }

    private func guessedType(of initializer: String) throws -> String? {
        let crawler = Crawler.crawl(source: "class Service {\n    var value = \(initializer)\n}\n", url: URL(filePath: "/project/Service.swift"))
        let service = try #require(crawler.tokens.first as? ClassDeclaration)
        return service.members.compactMap { $0 as? Variable }.first?.type.description
    }
}
