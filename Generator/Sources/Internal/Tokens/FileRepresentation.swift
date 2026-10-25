import Foundation

struct FileRepresentation: @unchecked Sendable {
    let file: TextFile
    let imports: [Import]
    let tokens: [any Token]

    init(file: TextFile, imports: [Import], tokens: [any Token]) {
        self.file = file
        self.imports = imports
        self.tokens = tokens
    }

    func replacing(tokens: [any Token]) -> FileRepresentation {
        FileRepresentation(file: file, imports: imports, tokens: tokens)
    }
}

extension FileRepresentation {
    func mergingInheritance(with files: [FileRepresentation]) -> FileRepresentation {
        let mergedTokens = tokens.reduce([] as [any Token]) { list, token in
            let mergeToken = token.mergingInheritance(with: files)
            return list + [mergeToken]
        }
        return replacing(tokens: mergedTokens)
    }

    func inheritNSObject(protocols: [ProtocolDeclaration]) -> FileRepresentation {
        replacing(tokens: tokens.map { $0.inheritingNSObject(protocols: protocols) })
    }

    func flatMappingMemberContainers() -> FileRepresentation {
        replacing(tokens: tokens.flatMap { $0.flatMappingMemberContainers() })
    }
}

extension Token {
    // TODO: This would be much better as a dictionary instead of going through all the files for every inheritance type.
    private static func findToken(forClassOrProtocol name: String, in files: [FileRepresentation]) -> (any Token)? {
        files.lazy
            .flatMap { $0.tokens }
            .filter { $0.isClass || $0.isProtocol }
            .compactMap { $0 as? any HasName }
            .first { $0.name == name }
    }

    fileprivate func mergingInheritance(with files: [FileRepresentation]) -> any Token {
        guard let token = self as? any Token & HasMembers & HasInheritance else { return self }

        let inheritedRepresentations = token.inheritedTypes
            .compactMap { Self.findToken(forClassOrProtocol: $0, in: files) }
            .compactMap { $0.mergingInheritance(with: files) }

        let mergedTokens = inheritedRepresentations
            .compactMap { $0 as? any HasMembers }
            .flatMap { $0.members }
            .reduce(token.members) { tokens, inheritedToken in
                guard let inheritedInheritable = inheritedToken as? any Inheritable else {
                    return tokens + [inheritedToken]
                }

                let isAlreadyPresent = tokens.compactMap({ $0 as? any Inheritable }).contains(where: { $0.isEqual(to: inheritedInheritable) })

                return isAlreadyPresent || !inheritedInheritable.isInheritable ? tokens : tokens + [inheritedToken]
            }

        switch token {
        case let classToken as ClassDeclaration:
            return classToken.replacing(members: mergedTokens)
        case let protocolToken as ProtocolDeclaration:
            return protocolToken.replacing(members: mergedTokens)
        default:
            assertionFailure("This case should not be possible.")
            return token
        }
    }

    fileprivate func inheritingNSObject(protocols: [ProtocolDeclaration]) -> any Token {
        guard let protocolToken = self as? ProtocolDeclaration, !protocolToken.isNSObjectProtocol else { return self }
        return protocols.contains { $0.name == protocolToken.name } ? protocolToken.replacing(isNSObjectProtocol: true) : self
    }
}

extension Token {
    fileprivate func flatMappingMemberContainers() -> [any Token] {
        guard let selfHasMembers = self as? any HasMembers else { return [self] }
        return [self] + selfHasMembers.members.flatMap { token in
            if let hasMembers = token as? any HasMembers {
                return hasMembers.flatMappingMemberContainers()
            } else {
                return []
            }
        }
    }
}
