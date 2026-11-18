import RegexBuilder

extension Method {
    struct Signature: Sendable {
        let genericParameters: [GenericParameter]
        let parameters: [MethodParameter]
        let asyncType: AsyncType?
        let throwType: ThrowType?
        let returnType: ComplexType?
        let whereConstraints: [String]

        init(
            genericParameters: [GenericParameter],
            parameters: [MethodParameter],
            asyncType: AsyncType? = nil,
            throwType: ThrowType? = nil,
            returnType: ComplexType? = nil,
            whereConstraints: [String]
        ) {
            self.genericParameters = genericParameters
            self.parameters = parameters.enumerated().map { index, parameter in
                MethodParameter(
                    parent: parameter.parent,
                    name: parameter.name,
                    innerName: "p\(index)",
                    type: parameter.type,
                    isNoncopyable: parameter.isNoncopyable,
                    variadicElement: parameter.variadicElement,
                    defaultValue: parameter.defaultValue,
                    isSubscriptKey: parameter.isSubscriptKey
                )
            }
            self.asyncType = asyncType
            self.throwType = throwType
            self.returnType = returnType
            self.whereConstraints = whereConstraints
        }

        var description: String {
            description(parameters: parameters.map(\.description))
        }

        /// The signature as an override declares it, with the parameters' default values.
        var declarationDescription: String {
            description(parameters: parameters.map(\.declarationDescription))
        }

        private func description(parameters: [String]) -> String {
            let genericParametersString = genericParameters.map { $0.description }.joined(separator: ", ")
            let returnString: String? = if let returnType, !returnType.isVoid {
                "-> \(returnType.description)"
            } else {
                nil
            }
            let whereString = whereConstraints.isEmpty ? nil : "where \(whereConstraints.joined(separator: ", "))"
            return [
                genericParametersString.isEmpty ? nil : "<\(genericParametersString)>",
                "(\(parameters.joined(separator: ", ")))",
                asyncType?.description,
                throwType?.description,
                returnString,
                whereString,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
    }
}

extension Method.Signature {
    /// The type names the sources declare, while their inheritance is merged: `Swift.Result` and `Result` differ
    /// when the sources declare a `Result` of their own.
    @TaskLocal static var declaredTypes: Set<String> = []

    /// Whether the two declare the same requirement, however they spell it: generic parameters named differently,
    /// a constraint written in the parameter list or in a `where` clause, or a standard type qualified as `Swift.Int`.
    func isApiEqual(to other: Method.Signature) -> Bool {
        guard genericParameters.map(\.kind) == other.genericParameters.map(\.kind),
              parameters.count == other.parameters.count,
              asyncType == other.asyncType,
              throwType == other.throwType else { return false }
        let mine = canonicalForm, theirs = other.canonicalForm
        return mine.types == theirs.types && mine.constraints == theirs.constraints
            && parameters.elementsEqual(other.parameters) { $0.name == $1.name }
    }

    /// The parameters' and result's types and the generic constraints, with the generic parameters renamed by
    /// position and `Swift.` left out, and without spaces.
    private var canonicalForm: (types: [String], constraints: Set<String>) {
        // Renamed in the order the parameters' and result's types first use them, so `h<U, T>(a: T, b: U)` is
        // `h<T, U>(a: T, b: U)`; one they don't use keeps its place after them.
        let signatureText = (parameters.map(\.type.description) + [returnType?.description ?? ""]).joined(separator: ",")
        let names = genericParameters.map(\.name).sorted { first, second in
            let firstUse = signatureText.firstRange(of: Regex { Anchor.wordBoundary; first; Anchor.wordBoundary }.wordBoundaryKind(.simple))?.lowerBound
            let secondUse = signatureText.firstRange(of: Regex { Anchor.wordBoundary; second; Anchor.wordBoundary }.wordBoundaryKind(.simple))?.lowerBound
            switch (firstUse, secondUse) {
            case let (first?, second?): return first < second
            case (_?, nil): return true
            default: return false
            }
        }
        func canonical(_ text: String) -> String {
            let declared = Self.declaredTypes
            var text = text.replacing(/\bSwift\.(\w+)/.wordBoundaryKind(.simple)) { match in
                declared.contains(String(match.output.1)) ? String(match.output.0) : String(match.output.1)
            }
            for (index, name) in names.enumerated() {
                text = text.replacing(Regex { Anchor.wordBoundary; name; Anchor.wordBoundary }.wordBoundaryKind(.simple), with: "__G\(index)")
            }
            return text.filter { !$0.isWhitespace }
        }
        let types = parameters.map { canonical($0.type.description) } + [returnType.map { canonical($0.description) } ?? "Void"]
        let constraints = genericParameters.flatMap { parameter in parameter.inheritedTypes.map { "\(parameter.name): \($0)" } } + whereConstraints
        return (types, Set(constraints.map(canonical)))
    }
}

extension Method.Signature {
    func containsType(named typeName: String) -> Bool {
        parameters.map(\.type)
            .contains(where: { $0.containsType(named: typeName) })
    }
    
    func containsTypes(named typeNames: [String]) -> Bool {
        typeNames.contains(where: { containsType(named: $0) })
    }
}
