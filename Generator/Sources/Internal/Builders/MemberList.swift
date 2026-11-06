import SwiftSyntax

/// A generated type's members, each on its own line, with a blank line where the layout calls for one.
struct MemberList {
    private(set) var list = MemberBlockItemListSyntax()
    private var separated = false

    /// The next member starts after a blank line.
    mutating func separate() {
        separated = true
    }

    mutating func append(_ source: String, of declaration: String) throws {
        var member = try Fragment.member(source, of: declaration)
        // A comment before the member stays; the newlines and indentation before it are replaced.
        let comments = member.leadingTrivia.pieces.drop { $0.isNewline || $0.isSpaceOrTab }
        member.leadingTrivia = .newlines(separated ? 2 : 1) + Trivia(pieces: Array(comments))
        separated = false
        list.append(member)
    }

    /// A member without a `#if` around it is set off by a blank line; one with a `#if` follows on the next line.
    mutating func append(_ token: any HasAttributes, source: String, of declaration: String) throws {
        if !token.hasCompilationCondition {
            separate()
        }
        try append(conditional(token, source), of: declaration)
    }

    /// The member inside its `#if`, if it has one.
    func conditional(_ member: any HasAttributes, _ source: String) -> String {
        member.hasCompilationCondition ? [member.compilationConditionCheck, source, "#endif"].joined(separator: "\n") : source
    }
}

extension Accessibility {
    /// The keyword followed by a space, or nothing for the default access level.
    var spaced: String {
        sourceName.isEmpty ? "" : "\(sourceName) "
    }
}
