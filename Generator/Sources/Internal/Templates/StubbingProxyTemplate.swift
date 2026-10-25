import Foundation

extension Templates {
    /// - Parameter isStatic: whether the proxy is for the mock type's static members (`stub(MockX.self)`), or its
    ///   instance members.
    static func stubbingProxy(isStatic: Bool) -> String {
        let name = isStatic ? "__StaticStubbingProxy_" : "__StubbingProxy_"
        let members = isStatic ? ["staticProperties", "staticMethods", "staticSubscripts"] : ["properties", "methods", "subscripts"]
        return """
{{ container.accessibility|withSpace }}nonisolated struct \(name){{ container.name }}: Cuckoo.StubbingProxy {
    private let cuckoo_manager: Cuckoo.MockManager

    {{ container.accessibility|withSpace }}init(manager: Cuckoo.MockManager) {
        self.cuckoo_manager = manager
    }
    {% for property in container.\(members[0]) %}
    {{ property.compilationConditionCheck }}
    {% for attribute in property.attributes %}
    {{ attribute }}
    {% endfor %}
    var {{property.name}}: Cuckoo.{{ property.stubType }}<{{ container.mockName }}, {{ property.stubGenericArguments|genericSafe }}> {
        return .init(manager: cuckoo_manager, name: "{{property.name}}")
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
    func {{method.name|escapeReservedKeywords}}{{method.self|matchableGenericNames}}({{method.parameters|matchableParameterSignature}}) -> {{method.stubFunction}}<({{method.stubInputTypes|genericSafe}}){%if method.returnType != "Void" %}, {{method.stubReturnType|genericSafe}}{%endif%}{% if method.isThrowing %},{{ method.throwTypeError }}{% endif %}, {{ method.stubImplementationType|genericSafe }}, {{ method.sharingType }}>{{method.self|matchableGenericWhereClause}} {
        {{method.parameters|parameterMatchers}}
        return .init(stub: cuckoo_manager.createStub(for: {{ container.mockName }}.self,
            method: "{{method.fullyQualifiedName}}",
            parameterMatchers: matchers
        ))
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
        return .init(cuckoo_manager: cuckoo_manager, matchers: matchers)
    }

    {% for attribute in subscript.attributes %}
    {{ attribute }}
    {% endfor %}
    nonisolated struct __Subscript{{ forloop.counter }}{{ subscript.genericParameters }}{{ subscript.whereClause }} {
        fileprivate let cuckoo_manager: Cuckoo.MockManager
        fileprivate let matchers: [Cuckoo.ParameterMatcher<({{ subscript.getter.stubInputTypes|genericSafe }})>]

        var get: {{ subscript.getter.stubFunction }}<({{ subscript.getter.stubInputTypes|genericSafe }}), {{ subscript.getter.stubReturnType|genericSafe }}{% if subscript.getter.isThrowing %}, {{ subscript.getter.throwTypeError }}{% endif %}, {{ subscript.getter.stubImplementationType|genericSafe }}, {{ subscript.getter.sharingType }}> {
            return .init(stub: cuckoo_manager.createStub(for: {{ container.mockName }}.self,
                method: "{{ subscript.getter.fullyQualifiedName }}",
                parameterMatchers: matchers
            ))
        }
        {% ifnot subscript.isReadOnly %}

        func set<{{ subscript.newValueMatcherGeneric }}>(_ {{ subscript.newValueName }}: M{{ subscript.newValueMatcherIndex }}) -> {{ subscript.setter.stubFunction }}<({{ subscript.setter.stubInputTypes|genericSafe }}), {{ subscript.setter.stubImplementationType|genericSafe }}, {{ subscript.setter.sharingType }}> where {{ subscript.newValueMatcherConstraint }} {
            let matchers: [Cuckoo.ParameterMatcher<({{ subscript.setter.stubInputTypes|genericSafe }})>] = {{ subscript.keyMatchers }}[{{ subscript.newValueMatcher }}]
            return .init(stub: cuckoo_manager.createStub(for: {{ container.mockName }}.self,
                method: "{{ subscript.setter.fullyQualifiedName }}",
                parameterMatchers: matchers
            ))
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
