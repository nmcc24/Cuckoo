struct Variable: Token, HasAccessibility, HasAttributes {
    struct Effects {
        var isThrowing = false
        var isAsync = false
    }

    var parent: Reference<Token>?

    var documentation: [String]
    var attributes: [Attribute]
    var accessibility: Accessibility
    var setterAccessibility: Accessibility?
    var name: String
    var type: ComplexType
    var effects: Effects
    /// The `#if` conditions the declaration is nested in.
    var compilationConditions: [String] = []
    /// The member's own isolation, if it states one.
    var isolation: Isolation?
    var isReadOnly: Bool {
        setterAccessibility?.isAccessible != true
    }
    // This flag is used to block generating inherited variables if the property to be overridden
    // is a constant, which Swift doesn't allow.
    var isConstant: Bool

    func serialize() -> [String: Any] {
        let readOnlyVerifyString = isReadOnly ? "ReadOnly" : ""
        let readOnlyStubString = effects.isThrowing ? "" : readOnlyVerifyString
        let optionalString = type.isOptional && !isReadOnly ? "Optional" : ""
        let throwingString = effects.isThrowing ? "Throwing" : ""

        guard let parent else {
            fatalError("Failed to find parent of variable \(name). Please file a bug.")
        }

        let stubIsolation = parent.value.stubIsolation(forMember: isolation)
        let storedType = isReadOnly ? type : type.unoptionaled
        let valueType = type.description
        // An actor mock's closures take the mock first.
        let isolatedParameter = stubIsolation.isolatedParameter
        let getterType = stubIsolation.implementationType(
            input: isolatedParameter.map { "(\($0))" } ?? "(())",
            output: valueType,
            isAsync: effects.isAsync,
            throwsClause: effects.isThrowing ? "throws" : nil
        )
        let setterType = stubIsolation.implementationType(
            input: isolatedParameter.map { "(\($0), \(valueType))" } ?? "(\(valueType))",
            output: "Void",
            isAsync: false,
            throwsClause: nil
        )
        let stubGenericArguments = [
            storedType.description,
            getterType,
            isReadOnly || effects.isThrowing ? nil : setterType,
            stubIsolation.sharingType,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")

        return [
            "documentation": documentation,
            "getterImplementationType": getterType,
            "setterImplementationType": setterType,
            "getterImplementationArguments": isolatedParameter == nil ? "()" : "self",
            "setterImplementationArguments": isolatedParameter == nil ? "newValue" : "self, newValue",
            "stubGenericArguments": stubGenericArguments,
            "isolationAttribute": isolation?.sourceDescription ?? "",
            "isOverriding": parent.isClass,
            "name": name,
            "type": type.description,
            "nonOptionalType": type.unoptionaled.description,
            "accessibility": accessibility.sourceName,
            "isAsync": effects.isAsync,
            "isThrowing": effects.isThrowing,
            "isReadOnly": isReadOnly,
            "stubType": (parent.isClass ? "Class" : "Protocol") + "ToBeStubbed\(readOnlyStubString)\(optionalString)\(throwingString)Property",
            "verifyType": "Verify\(readOnlyVerifyString)\(optionalString)Property",
            "attributes": attributes,
            "hasCompilationCondition": hasCompilationCondition,
            "compilationConditionCheck": compilationConditionCheck,
        ]
    }
}

extension Variable: Inheritable {
    var isInheritable: Bool {
        !isConstant
    }

    func isEqual(to other: Inheritable) -> Bool {
        guard let other = other as? Variable else { return false }
        return name == other.name
    }
}
