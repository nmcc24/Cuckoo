import SwiftParser
import SwiftSyntax

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension String {
    /// A type written as `Parent<String, Int>`, without its generic arguments: `Parent`.
    var withoutGenericArguments: String {
        guard let openingBracket = firstIndex(of: "<") else { return self }
        return self[..<openingBracket].trimmedSpaces
    }

    /// A type's top-level generic arguments: `["String", "[Int: Bool]"]` for `Parent<String, [Int: Bool]>`, and
    /// `["(Int) -> String", "Int"]` for `Parent<(Int) -> String, Int>`.
    var genericArguments: [String] {
        let declaration = Parser.parse(source: "typealias __CuckooType = \(self)").statements.first?.item.as(TypeAliasDeclSyntax.self)
        let type = declaration?.initializer.value
        let clause = type?.as(IdentifierTypeSyntax.self)?.genericArgumentClause ?? type?.as(MemberTypeSyntax.self)?.genericArgumentClause
        return clause?.arguments.map { $0.argument.trimmedDescription } ?? []
    }
}
