import Foundation

extension Templates {
    static let stubbingProxy = """
{{ container.accessibility|withSpace }}nonisolated struct __StubbingProxy_{{ container.name }}: Cuckoo.StubbingProxy {
    private let cuckoo_manager: Cuckoo.MockManager

    {{ container.accessibility|withSpace }}init(manager: Cuckoo.MockManager) {
        self.cuckoo_manager = manager
    }
    {% for property in container.properties %}
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
    {% for method in container.methods %}
    {{ method.compilationConditionCheck }}
    {% for attribute in method.attributes %}
    {{ attribute }}
    {% endfor %}
    func {{method.name|escapeReservedKeywords}}{{method.self|matchableGenericNames}}({{method.parameters|matchableParameterSignature}}) -> {{method.stubFunction}}<({{method.genericInputTypes|genericSafe}}){%if method.returnType != "Void" %}, {{method.genericReturnType|genericSafe}}{%endif%}{% if method.isThrowing %},{{ method.throwTypeError }}{% endif %}, {{ method.implementationType|genericSafe }}, {{ method.sharingType }}>{{method.self|matchableGenericWhereClause}} {
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
    {% for subscript in container.subscripts %}
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
        fileprivate let matchers: [Cuckoo.ParameterMatcher<({{ subscript.getter.genericInputTypes|genericSafe }})>]

        var get: {{ subscript.getter.stubFunction }}<({{ subscript.getter.genericInputTypes|genericSafe }}), {{ subscript.getter.genericReturnType|genericSafe }}{% if subscript.getter.isThrowing %}, {{ subscript.getter.throwTypeError }}{% endif %}, {{ subscript.getter.implementationType|genericSafe }}, {{ subscript.getter.sharingType }}> {
            return .init(stub: cuckoo_manager.createStub(for: {{ container.mockName }}.self,
                method: "{{ subscript.getter.fullyQualifiedName }}",
                parameterMatchers: matchers
            ))
        }
        {% ifnot subscript.isReadOnly %}

        func set<{{ subscript.newValueMatcherGeneric }}>(_ {{ subscript.newValueName }}: M{{ subscript.newValueMatcherIndex }}) -> {{ subscript.setter.stubFunction }}<({{ subscript.setter.genericInputTypes|genericSafe }}), {{ subscript.setter.implementationType|genericSafe }}, {{ subscript.setter.sharingType }}> where {{ subscript.newValueMatcherConstraint }} {
            let matchers: [Cuckoo.ParameterMatcher<({{ subscript.setter.genericInputTypes|genericSafe }})>] = {{ subscript.keyMatchers }}[{{ subscript.newValueMatcher }}]
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
