extension Templates {
    static let noImplStub = """
{% for attribute in container.attributes %}
{{ attribute }}
{% endfor %}
{% for attribute in container.spiAttributes %}
{{ attribute }}
{% endfor %}
{{container.accessibility|withSpace}}{% if container.isNonisolatedProtocol %}nonisolated {%+ endif %}{% if container.isActor %}actor{% else %}final class{% endif %} {{ container.name }}Stub{{ container.genericParameters }}: {% if container.superclass %}{{ container.superclass }}, {% endif %}{{ container.name }}{% if container.isImplementation %}{{ container.genericArguments }}{% endif %} {
    {% if container.declaresSelfTypealias %}
    {{ container.accessibility|withSpace }}typealias \(SelfResolution.typealiasName) = {{ container.name }}Stub
    {% endif %}
    {% if not container.isImplementation %}
    {% for typealias in container.typealiases %}
    {{ container.accessibility|withSpace }}{{ typealias }}
    {% endfor %}
    {% endif %}
    {% for property in container.allProperties %}
    {{ property.compilationConditionCheck }}
    {% if debug %}
    // {{property}}
    {% endif %}
    {% for attribute in property.attributes %}
    {{ attribute }}
    {% endfor %}
    {% for attribute in property.spiAttributes %}
    {{ attribute }}
    {% endfor %}
    {% if property.isolationAttribute %}
    {{ property.isolationAttribute }}
    {% endif %}
    {{ property.accessibility|withSpace }}{% if property.isOverriding %}override {%+ endif %}{{ property.staticKeyword }}var {{ property.name }}: {{ property.type }} {
        get {%+ if property.isAsync %}async {%+ endif %}{% if property.isThrowing %}throws {%+ endif %}{
            return DefaultValueRegistry.defaultValue(for: ({{property.type|genericSafe|removeClosureArgumentNames}}).self)
        }
        {% ifnot property.isReadOnly %}
        set {}
        {% endif %}
    }
    {% if property.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}

    {% for initializer in container.initializers %}
    {{ initializer.compilationConditionCheck }}
    {% for attribute in initializer.spiAttributes %}
    {{ attribute }}
    {% endfor %}
    {{ initializer.accessibility|withSpace }}required init{{initializer.signature}} {}
    {% if initializer.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}

    {% for method in container.allMethods %}
    {{ method.compilationConditionCheck }}
    {% if debug %}
    // {{method}}
    {% endif %}
    {% for attribute in method.attributes %}
    {{ attribute }}
    {% endfor %}
    {% for attribute in method.spiAttributes %}
    {{ attribute }}
    {% endfor %}
    {% if method.isolationAttribute %}
    {{ method.isolationAttribute }}
    {% endif %}
    {% if method.executionAttribute %}
    {{ method.executionAttribute }}
    {% endif %}
    {{ method.accessibility|withSpace }}{% if method.isOverriding %}override {%+ endif %}{{ method.staticKeyword }}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
        return DefaultValueRegistry.defaultValue(for: ({{method.genericReturnType|genericSafe}}).self)
    }
    {% if method.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
    {% for subscript in container.allSubscripts %}

    {{ subscript.compilationConditionCheck }}
    {% for attribute in subscript.attributes %}
    {{ attribute }}
    {% endfor %}
    {% for attribute in subscript.spiAttributes %}
    {{ attribute }}
    {% endfor %}
    {% if subscript.isolationAttribute %}
    {{ subscript.isolationAttribute }}
    {% endif %}
    {{ subscript.accessibility|withSpace }}{% if subscript.isOverriding %}override {%+ endif %}{{ subscript.staticKeyword }}subscript{{ subscript.signature }} {
        get {{ subscript.getterEffects }}{
            return DefaultValueRegistry.defaultValue(for: ({{ subscript.getter.genericReturnType|genericSafe|removeClosureArgumentNames }}).self)
        }
        {% ifnot subscript.isReadOnly %}
        set {}
        {% endif %}
    }
    {% if subscript.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
}
"""
}
