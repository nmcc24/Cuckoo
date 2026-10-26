import Foundation

struct GenericParameter: Equatable {
    let name: String
    let inheritedTypes: [String]
    /// A type parameter pack, `each T`.
    var isPack = false

    var description: String {
        let declaredName = isPack ? "each \(name)" : name
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
                    isPack: contains { $0.name == parameterName && $0.isPack }
                )
            )
        }
        return mergedParameters
    }
}
