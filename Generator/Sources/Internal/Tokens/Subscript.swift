/// A subscript. The mock records its accessors as calls named after the subscript's signature with `#get` or
/// `#set`, as properties' accessors are, and stubs them through the method machinery: the getter is a method
/// taking the keys, the setter one taking the keys and then the new value.
struct Subscript: Token, HasAccessibility, HasAttributes {
    var parent: Reference<any Token>?

    var documentation: [String]
    var attributes: [Attribute]
    var accessibility: Accessibility
    var setterAccessibility: Accessibility?
    var genericParameters: [GenericParameter]
    var parameters: [MethodParameter]
    var returnType: ComplexType
    var whereConstraints: [String]
    /// The getter's effects.
    var isAsync: Bool
    var throwType: ThrowType?
    /// The `#if` conditions the declaration is nested in.
    var compilationConditions: [String] = []
    /// The member's own isolation, if it states one.
    var isolation: Isolation?
    /// A `static` or `class` subscript, recorded by the mock type's static manager.
    var isStatic = false
    /// Whether a key or the value names `Self`; see ``Token/resolvingSelf()``.
    var mentionsSelf = false
    /// The signature the accessors are recorded under, when it differs from the declared one: as written with `Self`.
    var recordedSignature: String?

    var isReadOnly: Bool {
        setterAccessibility?.isAccessible != true
    }

    /// The getter, as a method taking the keys and returning the value.
    var getter: Method {
        accessor(
            kind: "get",
            parameters: parameters,
            returnType: returnType,
            asyncType: isAsync ? .async : nil,
            throwType: throwType
        )
    }

    /// The setter, as a method taking the keys and then the new value.
    var setter: Method {
        accessor(
            kind: "set",
            parameters: parameters + [MethodParameter(name: "_", type: returnType)],
            returnType: .type("Void"),
            asyncType: nil,
            throwType: nil
        )
    }

    /// The subscript's own signature: `(_ p0: String) -> Int?`, with the parameters' inner names the accessors use.
    var signature: String {
        let generics = genericParameters.isEmpty ? "" : "<\(genericParameters.map(\.description).joined(separator: ", "))>"
        let whereClause = whereConstraints.isEmpty ? "" : " where \(whereConstraints.joined(separator: ", "))"
        // The accessors' signature gives the parameters their inner names.
        let keys = Method.Signature(genericParameters: [], parameters: parameters, whereConstraints: []).parameters
        return "\(generics)(\(keys.map(\.description).joined(separator: ", "))) -> \(returnType)\(whereClause)"
    }

    private func accessor(kind: String, parameters: [MethodParameter], returnType: ComplexType, asyncType: AsyncType?, throwType: ThrowType?) -> Method {
        Method(
            parent: parent,
            documentation: [],
            attributes: attributes,
            accessibility: accessibility,
            name: "subscript",
            signature: Method.Signature(
                genericParameters: genericParameters,
                parameters: parameters,
                asyncType: asyncType,
                throwType: throwType,
                returnType: returnType,
                whereConstraints: whereConstraints
            ),
            isOptional: false,
            compilationConditions: compilationConditions,
            isolation: isolation,
            recordedName: "\(isStatic ? "static " : "")subscript\(recordedSignature ?? signature)#\(kind)",
            isStatic: isStatic
        )
    }

}

extension Subscript {
    /// The generic parameters, in angle brackets, or nothing.
    var genericParametersClause: String {
        genericParameters.isEmpty ? "" : genericParameters.sourceDescription
    }

    /// The generic parameters' names, in angle brackets, or nothing.
    var genericArgumentsClause: String {
        genericParameters.isEmpty ? "" : "<\(genericParameters.map(\.name).joined(separator: ", "))>"
    }

    /// The `where` clause with a leading space, or nothing.
    var whereClause: String {
        whereConstraints.isEmpty ? "" : " where \(whereConstraints.joined(separator: ", "))"
    }

    /// The getter as the mock's subscript calls it: it forwards to `super[...]` and the default implementation's subscript.
    var mockedGetter: Method {
        var getter = getter
        let keyArguments = getter.signature.parameters.map(\.forwardingCall).joined(separator: ", ")
        getter.superclassCallOverride = "super[\(keyArguments)]"
        getter.defaultCallOverride = "__defaultImplStub.value[\(keyArguments)]"
        getter.mentionsSelf = mentionsSelf
        return getter
    }

    /// The setter as the mock's subscript calls it, assigning the new value through `super[...]` and the default
    /// implementation's subscript.
    var mockedSetter: Method {
        var setter = setter
        let keyArguments = getter.signature.parameters.map(\.forwardingCall).joined(separator: ", ")
        setter.superclassCallOverride = "super[\(keyArguments)] = \(newValueName)"
        setter.defaultCallOverride = "__defaultImplStub.value[\(keyArguments)] = \(newValueName)"
        setter.mentionsSelf = mentionsSelf
        return setter
    }

    /// The getter's effects, each followed by a space.
    var getterEffects: String {
        [isAsync ? "async" : nil, throwType?.description].compactMap { $0 }.map { "\($0) " }.joined()
    }

    /// The keys' types as a closure's parameter list names them.
    var keyTypes: String {
        getter.signature.parameters.map { $0.type.withoutAttributes(except: ["@escaping", "@MainActor", "@Sendable"]).genericArgumentSafe.description }.joined(separator: ", ")
    }

    /// The arguments that pass a closure's parameters to the subscript as its keys, `key: $0`.
    var keyClosureParameters: String {
        getter.signature.parameters.enumerated().map { index, key in key.name == "_" ? "$\(index)" : "\(key.name): $\(index)" }.joined(separator: ", ")
    }

    /// The setter's last parameter.
    private var newValue: MethodParameter {
        setter.signature.parameters[parameters.count]
    }

    var newValueName: String {
        escapeReservedKeywords(for: newValue.usableName)
    }

    // A stubbing or verification proxy's setter matches the keys with the matchers its subscript got, reading
    // them out of the setter's parameters, which are the keys and then the new value.

    /// The matchers of the keys, followed by ` + `, or nothing for a subscript without keys.
    var keyMatchers: String {
        let keys = parameters
        guard !keys.isEmpty else { return "" }
        let keyProjection = keys.count == 1 ? "$0.0" : "(\(keys.indices.map { "$0.\($0)" }.joined(separator: ", ")))"
        return "self.matchers.map { matcher in Cuckoo.ParameterMatcher { matcher.matches(\(keyProjection)) } } + "
    }

    /// The number in the new value's matcher's generic parameter, `M<n>`.
    var newValueMatcherIndex: Int {
        parameters.count + 1
    }

    private var matchedNewValueType: ComplexType {
        newValue.type.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe
    }

    var newValueMatcherGeneric: String {
        "M\(newValueMatcherIndex): Cuckoo.\(matchedNewValueType.isOptional ? "OptionalMatchable" : "Matchable")"
    }

    var newValueMatcherConstraint: String {
        let type = matchedNewValueType
        return "M\(newValueMatcherIndex).\(type.isOptional ? "OptionalMatchedType" : "MatchedType") == \(type.unoptionaled.description.replacing("!", with: "?"))"
    }

    var newValueMatcher: String {
        "Cuckoo.wrap(matchable: \(newValueName)) { \(parameters.isEmpty ? "$0" : "$0.\(parameters.count)") }"
    }
}

extension Subscript: Inheritable {
    func isEqual(to other: any Inheritable) -> Bool {
        guard let other = other as? Subscript else { return false }
        return isStatic == other.isStatic && getter.signature.isApiEqual(to: other.getter.signature)
    }
}
