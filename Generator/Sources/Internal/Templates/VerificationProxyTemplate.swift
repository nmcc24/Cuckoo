import Foundation

extension Templates {
    static let verificationProxy = """
{{ container.accessibility|withSpace }}nonisolated struct __VerificationProxy_{{ container.name }}: Cuckoo.VerificationProxy {
    private let cuckoo_manager: Cuckoo.MockManager
    private let callMatcher: Cuckoo.CallMatcher
    private let sourceLocation: Cuckoo.SourceLocation

    {{ container.accessibility|withSpace }}init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
        self.cuckoo_manager = manager
        self.callMatcher = callMatcher
        self.sourceLocation = sourceLocation
    }
    {% for property in container.properties %}
    
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
    {% for method in container.methods %}
    
    {{ method.compilationConditionCheck }}
    {% for attribute in method.attributes %}
    {{ attribute }}
    {% endfor %}
    @discardableResult
    func {{method.name|escapeReservedKeywords}}{{method.self|matchableGenericNames}}({{method.parameters|matchableParameterSignature}}) -> Cuckoo.__DoNotUse<({{method.genericInputTypes|genericSafe}}), {{method.genericReturnType|genericSafe}}>{{method.self|matchableGenericWhereClause}} {
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
    {% for subscript in container.subscripts %}

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
        fileprivate let matchers: [Cuckoo.ParameterMatcher<({{ subscript.getter.genericInputTypes|genericSafe }})>]

        @discardableResult
        func get() -> Cuckoo.__DoNotUse<({{ subscript.getter.genericInputTypes|genericSafe }}), {{ subscript.getter.genericReturnType|genericSafe }}> {
            return cuckoo_manager.verify(
                "{{ subscript.getter.fullyQualifiedName }}",
                callMatcher: callMatcher,
                parameterMatchers: matchers,
                sourceLocation: sourceLocation
            )
        }
        {% ifnot subscript.isReadOnly %}

        @discardableResult
        func set<{{ subscript.newValueMatcherGeneric }}>(_ {{ subscript.newValueName }}: M{{ subscript.newValueMatcherIndex }}) -> Cuckoo.__DoNotUse<({{ subscript.setter.genericInputTypes|genericSafe }}), Void> where {{ subscript.newValueMatcherConstraint }} {
            let matchers: [Cuckoo.ParameterMatcher<({{ subscript.setter.genericInputTypes|genericSafe }})>] = {{ subscript.keyMatchers }}[{{ subscript.newValueMatcher }}]
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
