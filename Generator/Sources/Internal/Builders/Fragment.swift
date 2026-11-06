import SwiftParser
import SwiftSyntax

/// Generated source, parsed piece by piece as it's built, so a piece that doesn't parse fails generation with the
/// declaration it came from instead of producing a file that doesn't compile.
enum Fragment {
    /// Parses `source` as one top-level declaration.
    static func declaration(_ source: String, of declaration: String) throws -> DeclSyntax {
        let tree = Parser.parse(source: source)
        guard !tree.hasError, tree.statements.count == 1, let item = tree.statements.first?.item.as(DeclSyntax.self) else {
            throw FragmentError.unparsable(declaration: declaration, source: source)
        }
        return item
    }

    /// Parses `source` as one member of a type, such as a property, a method, or either inside a `#if`.
    static func member(_ source: String, of declaration: String) throws -> MemberBlockItemSyntax {
        let tree = Parser.parse(source: "final class __CuckooFragment {\n\(source)\n}")
        guard !tree.hasError,
              tree.statements.count == 1,
              let type = tree.statements.first?.item.as(ClassDeclSyntax.self),
              type.memberBlock.members.count == 1,
              let member = type.memberBlock.members.first
        else {
            throw FragmentError.unparsable(declaration: declaration, source: source)
        }
        return member.detached
    }
    /// `value` as a Swift string literal, quoted and escaped, the way `\(literal:)` spells one in SwiftSyntaxBuilder.
    static func literal(_ value: String) -> String {
        var escaped = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            case "\0": escaped += "\\0"
            case _ where scalar.properties.generalCategory == .control:
                escaped += "\\u{\(String(scalar.value, radix: 16))}"
            default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped + "\""
    }
}

enum FragmentError: Error, CustomStringConvertible {
    case unparsable(declaration: String, source: String)

    var description: String {
        switch self {
        case .unparsable(let declaration, let source):
            return "The generated code for `\(declaration)` doesn't parse:\n\(source)\nPlease report this as a Cuckoo bug, with the declaration it mocks."
        }
    }
}
