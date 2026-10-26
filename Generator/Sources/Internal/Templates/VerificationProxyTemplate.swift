import Foundation

extension Templates {
    /// - Parameter isStatic: whether the proxy is for the mock type's static members (`stub(MockX.self)`), or its
    ///   instance members.
    static func verificationProxy(isStatic: Bool) -> String {
        let name = isStatic ? "__StaticVerificationProxy_" : "__VerificationProxy_"
        let members = isStatic ? ["staticProperties", "staticMethods", "staticSubscripts"] : ["properties", "methods", "subscripts"]
        return """
{{ container.accessibility|withSpace }}nonisolated struct \(name){{ container.name }}: Cuckoo.VerificationProxy {
    private let cuckoo_manager: Cuckoo.MockManager
    private let callMatcher: Cuckoo.CallMatcher
    private let sourceLocation: Cuckoo.SourceLocation

    {{ container.accessibility|withSpace }}init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
        self.cuckoo_manager = manager
        self.callMatcher = callMatcher
        self.sourceLocation = sourceLocation
    }
    {% for property in container.\(members[0]) %}
    
    {% if property.hasCompilationCondition %}
    {{ property.compilationConditionCheck }}
    {% endif %}
    {% for attribute in property.attributes %}
    {{ attribute }}
    {% endfor %}
    var {{property.name}}: Cuckoo.{{property.verifyType}}<{% if property.isReadOnly %}{{property.type|genericSafe}}{% else %}{{property.nonOptionalType|genericSafe}}{% endif %}> {
        return .init(manager: cuckoo_manager, name: "{{property.name}}", callMatcher: callMatcher, sourceLocation: sourceLocation)
    }
    {% if property.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
    {% for method in container.\(members[1]) %}
    
    {{ method.compilationConditionCheck }}
    {% for attribute in method.attributes %}
    {{ attribute }}
    {% endfor %}
    @discardableResult
    func {{method.name|escapeReservedKeywords}}{{method.self|matchableVerificationGenericNames}}({{method.parameters|matchableParameterSignature}}) -> Cuckoo.__DoNotUse<({{method.stubInputTypes|genericSafe}}), {{method.verificationReturnType|genericSafe}}>{{method.self|matchableVerificationGenericWhereClause}} {
        {{method.parameters|parameterMatchers}}
        return cuckoo_manager.verify(
            "{{method.fullyQualifiedName}}",
            callMatcher: callMatcher,
            parameterMatchers: matchers,
            sourceLocation: sourceLocation
        )
    }
    {% if method.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
    {% for subscript in container.\(members[2]) %}

    {{ subscript.compilationConditionCheck }}
    {% for attribute in subscript.attributes %}
    {{ attribute }}
    {% endfor %}
    subscript{{ subscript.getter.self|matchableGenericNames }}({{ subscript.getter.parameters|matchableParameterSignature }}) -> __Subscript{{ forloop.counter }}{{ subscript.genericArguments }}{{ subscript.getter.self|matchableGenericWhereClause }} {
        {{ subscript.getter.parameters|parameterMatchers }}
        return .init(cuckoo_manager: cuckoo_manager, callMatcher: callMatcher, sourceLocation: sourceLocation, matchers: matchers)
    }

    {% for attribute in subscript.attributes %}
    {{ attribute }}
    {% endfor %}
    nonisolated struct __Subscript{{ forloop.counter }}{{ subscript.genericParameters }}{{ subscript.whereClause }} {
        fileprivate let cuckoo_manager: Cuckoo.MockManager
        fileprivate let callMatcher: Cuckoo.CallMatcher
        fileprivate let sourceLocation: Cuckoo.SourceLocation
        fileprivate let matchers: [Cuckoo.ParameterMatcher<({{ subscript.getter.stubInputTypes|genericSafe }})>]

        @discardableResult
        func get() -> Cuckoo.__DoNotUse<({{ subscript.getter.stubInputTypes|genericSafe }}), {{ subscript.getter.stubReturnType|genericSafe }}> {
            return cuckoo_manager.verify(
                "{{ subscript.getter.fullyQualifiedName }}",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        {% ifnot subscript.isReadOnly %}

        @discardableResult
        func set<{{ subscript.newValueMatcherGeneric }}>(_ {{ subscript.newValueName }}: M{{ subscript.newValueMatcherIndex }}) -> Cuckoo.__DoNotUse<({{ subscript.setter.stubInputTypes|genericSafe }}), Void> where {{ subscript.newValueMatcherConstraint }} {
            let matchers: [Cuckoo.ParameterMatcher<({{ subscript.setter.stubInputTypes|genericSafe }})>] = {{ subscript.keyMatchers }}[{{ subscript.newValueMatcher }}]
            return cuckoo_manager.verify(
                "{{ subscript.setter.fullyQualifiedName }}",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        {% endif %}
    }
    {% if subscript.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
}
"""
    }
}
