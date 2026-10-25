extension Templates {
    static let noImplStub = """
{% for attribute in container.attributes %}
{{ attribute }}
{% endfor %}
{{container.accessibility|withSpace}}{% if container.isActor %}actor{% else %}final class{% endif %} {{ container.name }}Stub{{ container.genericParameters }}: {% if container.isNSObjectProtocol %}NSObject, {% endif %}{{ container.name }}{% if container.isImplementation %}{{ container.genericArguments }}{% endif %} {
    {% for property in container.properties %}
    {{ property.compilationConditionCheck }}
    {% if debug %}
    // {{property}}
    {% endif %}
    {% for attribute in property.attributes %}
    {{ attribute }}
    {% endfor %}
    {% if property.isolationAttribute %}
    {{ property.isolationAttribute }}
    {% endif %}
    {{ property.accessibility|withSpace }}{% if property.isOverriding %}override {%+ endif %}var {{ property.name }}: {{ property.type }} {
        get {
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
    {{ initializer.accessibility|withSpace }}required init{{initializer.signature}} {}
    {% if initializer.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}

    {% for method in container.methods %}
    {{ method.compilationConditionCheck }}
    {% if debug %}
    // {{method}}
    {% endif %}
    {% for attribute in method.attributes %}
    {{ attribute }}
    {% endfor %}
    {% if method.isolationAttribute %}
    {{ method.isolationAttribute }}
    {% endif %}
    {% if method.executionAttribute %}
    {{ method.executionAttribute }}
    {% endif %}
    {{ method.accessibility|withSpace }}{% if method.isOverriding %}override {%+ endif %}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
        return DefaultValueRegistry.defaultValue(for: ({{method.genericReturnType|genericSafe}}).self)
    }
    {% if method.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
}
"""
}
