struct Variable: Token, HasAccessibility, HasAttributes {
    struct Effects {
        var isThrowing = false
        var isAsync = false
    }

    var parent: Reference<any Token>?

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
    /// A `static` or `class` member, recorded by the mock type's static manager.
    var isStatic = false
    /// Whether the type names `Self`; see ``Token/resolvingSelf()``.
    var mentionsSelf = false

    /// The stub type the stubbing proxy returns, such as `ProtocolToBeStubbedReadOnlyProperty`.
    var stubType: String {
        let readOnlyStubString = effects.isThrowing || !isReadOnly ? "" : "ReadOnly"
        let optionalString = type.isOptional && !isReadOnly ? "Optional" : ""
        let throwingString = effects.isThrowing ? "Throwing" : ""
        return (parent?.isClass == true ? "Class" : "Protocol") + "ToBeStubbed\(readOnlyStubString)\(optionalString)\(throwingString)Property"
    }

    /// The isolation and sharing of the stub's `then` closures. An actor's static members aren't isolated to an instance.
    var stubIsolation: StubIsolation {
        guard let parent else {
            fatalError("Failed to find parent of variable \(name). Please file a bug.")
        }
        let stubbedIsolation: Isolation? = isStatic && isolation == nil && parent.value.asProtocol?.isActor == true ? .nonisolated : isolation
        return parent.value.stubIsolation(forMember: stubbedIsolation)
    }

    /// The `then` closure types of the getter and the setter. An actor mock's closures take the mock first.
    var implementationTypes: (getter: String, setter: String) {
        let stubIsolation = self.stubIsolation
        let valueType = type.description
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
        return (getterType, setterType)
    }

    /// The stub type's generic arguments after the mock's type.
    var stubGenericArguments: String {
        let storedType = isReadOnly ? type : type.unoptionaled
        let types = implementationTypes
        var arguments = [storedType.description, types.getter]
        if !isReadOnly && !effects.isThrowing {
            arguments.append(types.setter)
        }
        arguments.append(stubIsolation.sharingType)
        return arguments.joined(separator: ", ")
    }

    func serialize() -> [String: Any] {
        let readOnlyVerifyString = isReadOnly ? "ReadOnly" : ""
        let optionalString = type.isOptional && !isReadOnly ? "Optional" : ""

        guard let parent else {
            fatalError("Failed to find parent of variable \(name). Please file a bug.")
        }

        let (getterType, setterType) = implementationTypes
        let isolatedParameter = stubIsolation.isolatedParameter

        return [
            "documentation": documentation,
            "getterImplementationType": getterType,
            "setterImplementationType": setterType,
            "getterImplementationArguments": isolatedParameter == nil ? "()" : "self",
            "setterImplementationArguments": isolatedParameter == nil ? "value" : "self, value",
            "stubGenericArguments": stubGenericArguments,
            "isolationAttribute": isolation?.sourceDescription ?? "",
            "isOverriding": parent.isClass,
            "isStatic": isStatic,
            "mentionsSelf": mentionsSelf,
            "staticKeyword": isStatic ? "static " : "",
            "manager": isStatic ? "cuckoo_staticManager" : "cuckoo_manager",
            "name": name,
            "type": type.description,
            "nonOptionalType": type.unoptionaled.description,
            "accessibility": accessibility.sourceName,
            "isAsync": effects.isAsync,
            "isThrowing": effects.isThrowing,
            "isReadOnly": isReadOnly,
            "stubType": stubType,
            "verifyType": "Verify\(readOnlyVerifyString)\(optionalString)Property",
            "attributes": repeatedAttributes,
            "spiAttributes": spiAttributes(at: accessibility),
            "hasCompilationCondition": hasCompilationCondition,
            "compilationConditionCheck": compilationConditionCheck,
        ]
    }
}

extension Variable: Inheritable {
    var isInheritable: Bool {
        !isConstant
    }

    func isEqual(to other: any Inheritable) -> Bool {
        guard let other = other as? Variable else { return false }
        return name == other.name && isStatic == other.isStatic
    }
}
