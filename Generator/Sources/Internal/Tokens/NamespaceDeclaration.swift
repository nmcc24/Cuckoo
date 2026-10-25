import Foundation

/// This structure exists purely for supporting nested classes,
/// it could be any container (like `struct` or `extension`).
struct NamespaceDeclaration: Token, HasAccessibility, HasName, HasMembers, HasEnclosingCompilationConditions {
    var parent: Reference<any Token>?

    var attributes: [Attribute]
    var accessibility: Accessibility
    var name: String
    var members: [any Token]
    var enclosingCompilationConditions: [String]

    func replacing(members: [any Token]) -> NamespaceDeclaration {
        NamespaceDeclaration(
            parent: parent,
            attributes: attributes,
            accessibility: accessibility,
            name: name,
            members: members,
            enclosingCompilationConditions: enclosingCompilationConditions
        )
    }
}
