struct GenericParameter: Equatable {
    /// What a generic parameter is, beyond a plain type parameter.
    enum Kind: Equatable {
        case type
        /// A type parameter pack, `each T`.
        case pack
        /// A value generic, `let N: Int`.
        case value
    }

    let name: String
    let inheritedTypes: [String]
    var kind = Kind.type

    var isPack: Bool {
        kind == .pack
    }

    var description: String {
        let declaredName = switch kind {
        case .type: name
        case .pack: "each \(name)"
        case .value: "let \(name)"
        }
        if inheritedTypes.isEmpty {
            return declaredName
        } else {
            return "\(declaredName): \(inheritedTypes.joined(separator: " & "))"
        }
    }
}

extension Array where Element == GenericParameter {
    var sourceDescription: String {
        "<\(map { $0.description }.joined(separator: ", "))>"
    }

    func merged() -> [GenericParameter] {
        var seenNames: Set<String> = []
        var mergedParameters: [GenericParameter] = []
        for parameterName in self.map(\.name) where !seenNames.contains(parameterName) {
            seenNames.insert(parameterName)
            let mergedInheritedTypes = filter { $0.name == parameterName }.flatMap(\.inheritedTypes).uniquing()
            mergedParameters.append(
                GenericParameter(
                    name: parameterName,
                    inheritedTypes: mergedInheritedTypes,
                    kind: first { $0.name == parameterName }?.kind ?? .type
                )
            )
        }
        return mergedParameters
    }
}
