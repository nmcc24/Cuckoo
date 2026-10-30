import SwiftParser
import SwiftSyntax

/// A type a source file declares at the top level, which the generated file imports by name from the source's
/// module. A scoped import beats every whole-module import, so the name means this type in the mocks even where
/// another imported module declares the same name.
struct TopLevelType: Hashable, Sendable {
    /// The import kind: `struct`, `class` (also for an actor), `enum`, `protocol` or `typealias`.
    let kind: String
    let name: String
    let accessibility: Accessibility
    /// The `#if` conditions the declaration is nested in.
    let compilationConditions: [String]
}

extension Crawler {
    static func topLevelTypes(in source: String) -> [TopLevelType] {
        topLevelTypes(in: Parser.parse(source: source).statements, conditions: [])
    }

    private static func topLevelTypes(in items: CodeBlockItemListSyntax, conditions: [String]) -> [TopLevelType] {
        items.flatMap { item -> [TopLevelType] in
            guard let declaration = item.item.as(DeclSyntax.self) else { return [] }
            if let ifConfig = declaration.as(IfConfigDeclSyntax.self) {
                return topLevelTypes(in: ifConfig, conditions: conditions)
            }
            let named: (kind: String, name: TokenSyntax, modifiers: DeclModifierListSyntax)? =
                if let node = declaration.as(StructDeclSyntax.self) {
                    ("struct", node.name, node.modifiers)
                } else if let node = declaration.as(ClassDeclSyntax.self) {
                    ("class", node.name, node.modifiers)
                } else if let node = declaration.as(ActorDeclSyntax.self) {
                    ("class", node.name, node.modifiers)
                } else if let node = declaration.as(EnumDeclSyntax.self) {
                    ("enum", node.name, node.modifiers)
                } else if let node = declaration.as(ProtocolDeclSyntax.self) {
                    ("protocol", node.name, node.modifiers)
                } else if let node = declaration.as(TypeAliasDeclSyntax.self) {
                    ("typealias", node.name, node.modifiers)
                } else {
                    nil
                }
            guard let named else { return [] }
            let accessibility = named.modifiers.lazy.compactMap { Accessibility(tokenKind: $0.name.tokenKind) }.first ?? .internal
            guard accessibility.isAccessible else { return [] }
            return [TopLevelType(kind: named.kind, name: named.name.text, accessibility: accessibility, compilationConditions: conditions)]
        }
    }

    /// Each clause's declarations get the clause's full condition, as the crawler gives members.
    private static func topLevelTypes(in ifConfig: IfConfigDeclSyntax, conditions: [String]) -> [TopLevelType] {
        var previousConditions: [String] = []
        var types: [TopLevelType] = []
        for clause in ifConfig.clauses {
            let condition = clause.condition.map { "(\($0.trimmedDescription))" }
            let clauseCondition = (previousConditions.map { "!\($0)" } + [condition].compactMap { $0 }).joined(separator: " && ")
            if case .statements(let statements) = clause.elements {
                types += topLevelTypes(in: statements, conditions: conditions + [clauseCondition])
            }
            condition.map { previousConditions.append($0) }
        }
        return types
    }
}
