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
        ("Swift.Int(3)", "Swift.Int"),
        ("Array<Int>()", "Array<Int>"),
        ("value as Double", "Double"),
        ("value as! [Int]", "[Int]"),
        ("value as? any Sendable", "Optional<any Sendable>"),
        ("[1, 2]", "[Int]"),
        ("[\"a\": 1.5]", "[String: Double]"),
        ("Array(repeating: 0, count: 3)", "[Int]"),
        ("Int(3)", "Int"),
        ("String(describing: value)", "String"),
        ("String(repeating: \"a\", count: 3)", "String"),
        ("String(value)", "String"),
    ])
    func initializerNamesTheType(initializer: String, type: String) throws {
        #expect(try guessedType(of: initializer) == type)
    }

    @Test(arguments: [
        "Retries(3)",
        "Retries.init(3)",
        "Outer.Inner()",
        "Box<Int>()",
        "URL(filePath: path)",
        "Style.default",
        "UUID().uuidString",
        "makeConnection()",
        "Factory.make()",
        "[1, 2.5]",
        "[]",
        "[makeConnection()]",
        "Array()",
        "Dictionary(uniqueKeysWithValues: pairs)",
        "URL(string: text)",
        "UUID(uuidString: text)",
        "Int(text)",
        "Double(\"1.5\")",
        "Bool(\"true\")",
        "String(data: data, encoding: .utf8)",
        "String(validatingCString: pointer)",
        "Range<Int>(nsRange)",
        ".init()",
        "-value",
        "a + b",
    ])
    func initializerThatDoesNotNameATypeIsSkipped(initializer: String) throws {
        #expect(try guessedType(of: initializer) == nil)
    }

    /// A call of a type that isn't the standard library's isn't read as the type it names, as it may be a failable
    /// initializer or an enum case; nor is a generic type without arguments, called or annotated.
    @Test(arguments: [
        "struct Maybe { init?(text: String) {} }\nclass Service {\n    var value = Maybe(text: \"a\")\n}",
        "enum Kind: Int { case one = 1 }\nclass Service {\n    var value = Kind(rawValue: 1)\n}",
        "enum Shape { case Circle(Int) }\nclass Service {\n    var value = Shape.Circle(3)\n}",
        "class Service {\n    var value = Task { 1 }\n}",
        "class Service {\n    var value: Array = [1]\n}",
    ])
    func unclearInitializerIsSkipped(source: String) throws {
        let crawler = Crawler.crawl(source: source, url: URL(filePath: "/project/Service.swift"))
        let service = try #require(crawler.tokens.compactMap { $0 as? ClassDeclaration }.first)
        #expect(service.members.isEmpty)
    }

    private func guessedType(of initializer: String) throws -> String? {
        let crawler = Crawler.crawl(source: "class Service {\n    var value = \(initializer)\n}\n", url: URL(filePath: "/project/Service.swift"))
        let service = try #require(crawler.tokens.first as? ClassDeclaration)
        return service.members.compactMap { $0 as? Variable }.first?.type.description
    }
}
