import Foundation

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
    private var signature: String {
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
            recordedName: "\(isStatic ? "static " : "")subscript\(signature)#\(kind)",
            isStatic: isStatic
        )
    }

    func serialize() -> [String: Any] {
        guard let parent else {
            fatalError("Failed to find parent of subscript \(signature). Please file a bug.")
        }

        let getter = getter
        let setter = setter
        let keys = getter.signature.parameters
        let newValue = setter.signature.parameters[keys.count]
        let keyArguments = keys.map(\.forwardingCall).joined(separator: ", ")
        let newValueName = escapeReservedKeywords(for: newValue.usableName)

        var serializedGetter = getter.serialize()
        serializedGetter["superclassCall"] = "super[\(keyArguments)]"
        if !isStatic {
            serializedGetter["defaultCall"] = "__defaultImplStub.value[\(keyArguments)]"
        }
        var serializedSetter = setter.serialize()
        serializedSetter["superclassCall"] = "super[\(keyArguments)] = \(newValueName)"
        if !isStatic {
            serializedSetter["defaultCall"] = "__defaultImplStub.value[\(keyArguments)] = \(newValueName)"
        }

        // A stubbing or verification proxy's setter matches the keys with the matchers its subscript got, reading
        // them out of the setter's parameters, which are the keys and then the new value.
        let keyProjection = keys.count == 1 ? "$0.0" : "(\(keys.indices.map { "$0.\($0)" }.joined(separator: ", ")))"
        let keyMatchers = keys.isEmpty ? "" : "self.matchers.map { matcher in Cuckoo.ParameterMatcher { matcher.matches(\(keyProjection)) } } + "
        let newValueProjection = keys.isEmpty ? "$0" : "$0.\(keys.count)"
        let matchedNewValueType = newValue.type.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe
        let newValueMatcherIndex = keys.count + 1

        return [
            "self": self,
            "documentation": documentation,
            "attributes": attributes,
            "isOverriding": parent.isClass,
            "isStatic": isStatic,
            "staticKeyword": isStatic ? "static " : "",
            "accessibility": accessibility.sourceName,
            "signature": signature,
            "genericParameters": genericParameters.isEmpty ? "" : genericParameters.sourceDescription,
            "genericArguments": genericParameters.isEmpty ? "" : "<\(genericParameters.map(\.name).joined(separator: ", "))>",
            "whereClause": whereConstraints.isEmpty ? "" : " where \(whereConstraints.joined(separator: ", "))",
            "returnType": returnType.description,
            "isAsync": isAsync,
            "isThrowing": throwType != nil,
            "getterEffects": [isAsync ? "async" : nil, throwType?.description].compactMap { $0 }.map { "\($0) " }.joined(),
            "isReadOnly": isReadOnly,
            "hasGenericParams": !genericParameters.isEmpty,
            "isolationAttribute": isolation?.sourceDescription ?? "",
            "getter": serializedGetter,
            "setter": serializedSetter,
            // The setter lists hold the one accessor, so a template's `for` can name it `method`.
            "getters": [serializedGetter],
            "setters": isReadOnly ? [] : [serializedSetter],
            "keyMatchers": keyMatchers,
            "keyCount": keys.count,
            "newValueName": newValueName,
            "newValueMatcherIndex": newValueMatcherIndex,
            "newValueMatcherGeneric": "M\(newValueMatcherIndex): Cuckoo.\(matchedNewValueType.isOptional ? "OptionalMatchable" : "Matchable")",
            "newValueMatcherConstraint": "M\(newValueMatcherIndex).\(matchedNewValueType.isOptional ? "OptionalMatchedType" : "MatchedType") == \(matchedNewValueType.unoptionaled.description.replacingOccurrences(of: "!", with: "?"))",
            "newValueMatcher": "wrap(matchable: \(newValueName)) { \(newValueProjection) }",
            "keyClosureParameters": keys.enumerated().map { index, key in key.name == "_" ? "$\(index)" : "\(key.name): $\(index)" }.joined(separator: ", "),
            "keyTypes": keys.map { $0.type.withoutAttributes(except: ["@escaping", "@MainActor", "@Sendable"]).genericArgumentSafe.description }.joined(separator: ", "),
            "hasCompilationCondition": hasCompilationCondition,
            "compilationConditionCheck": compilationConditionCheck,
        ]
    }
}

extension Subscript: Inheritable {
    func isEqual(to other: any Inheritable) -> Bool {
        guard let other = other as? Subscript else { return false }
        return isStatic == other.isStatic && getter.signature.isApiEqual(to: other.getter.signature)
    }
}
