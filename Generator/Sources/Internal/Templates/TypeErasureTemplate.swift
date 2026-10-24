import Foundation

extension Templates {
    static let typeErasure = """
    {{ container.accessibility|withSpace }}class \(typeErasureClassName): {{ container.name }}, @unchecked Sendable {
        private let reference: () -> any {{ container.name }}{{ container.genericPrimaryAssociatedTypeArguments }}

        {% for property in container.properties %}
        {% if property.hasCompilationCondition %}
        {{ property.compilationConditionCheck }}
        {% endif %}
        private let _getter_storage$${{ property.name }}: () -> {{ property.type }}
        {% if not property.isReadOnly %}
        private let _setter_storage$${{ property.name }}: ({{ property.type }}) -> Void
        {% endif %}
        {{ container.accessibility|withSpace }}var {{ property.name }}: {{ property.type }} {
            get { return _getter_storage$${{ property.name }}() }
            {% if not property.isReadOnly %}
            set { _setter_storage$${{ property.name }}(newValue) }
            {% endif %}
        }
        {% if property.hasCompilationCondition %}
        #endif
        {% endif %}

        {% endfor %}
        {# For developers: The `keeping reference: Any` is necessary because when called from the `enableDefaultImplementation(stub:)` method
        instead of `enableDefaultImplementation(mutating:)`, we need to prevent the struct getting deallocated. #}
        init<\(staticGenericParameter): {{ container.name }}>(from defaultImpl: UnsafeMutablePointer<\(staticGenericParameter)>, keeping reference: @escaping @autoclosure () -> \(staticGenericParameter)) where {{ container.genericProtocolIdentity }} {
            self.reference = reference

            {% for property in container.properties %}
            {% if property.hasCompilationCondition %}
            {{ property.compilationConditionCheck }}
            {% endif %}
            _getter_storage$${{ property.name }} = { defaultImpl.pointee.{{ property.name }} }
            {% if not property.isReadOnly %}
            _setter_storage$${{ property.name }} = { defaultImpl.pointee.{{ property.name }} = $0 }
            {% endif %}
            {% if property.hasCompilationCondition %}
            #endif
            {% endif %}
            {% endfor %}
            {% for method in container.methods %}
            {% if not method.hasGenericParams %}
            {% if method.hasCompilationCondition %}
            {{ method.compilationConditionCheck }}
            {% endif %}
            _storage${{ forloop.counter }}${{ method.name }} = defaultImpl.pointee.{{ method.name }}
            {% if method.hasCompilationCondition %}
            #endif
            {% endif %}
            {% endif %}
            {% endfor %}
        }
        {% if container.initializers %}
        /// MARK:- ignored required initializers
        {% endif %}
        {% for initializer in container.initializers %}
        {% if initializer.hasCompilationCondition %}
        {{ initializer.compilationConditionCheck }}
        {% endif %}
        {{ container.accessibility|withSpace }}required init{{initializer.signature}} {
            fatalError("`DefaultImplCaller` class is only used for calling default implementation and can't be initialized on its own.")
        }
        {% if initializer.hasCompilationCondition %}
        #endif
        {% endif %}
        {% endfor %}

        {% for method in container.methods +%}
        {% if method.hasCompilationCondition %}
        {{ method.compilationConditionCheck }}
        {% endif %}
        {% if not method.hasGenericParams %}
        private let _storage${{ forloop.counter }}${{ method.name }}: ({{ method.inputTypes }}) {% if method.isAsync %} async{% endif %} {% if method.isThrowing %} throws{% endif %} -> {{ method.returnType }}
        {% endif %}
        {{ container.accessibility|withSpace }}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
            {% if method.hasGenericParams and method.hasNonPrimaryAssociatedTypeParams %}
            {# A `sending` argument is passed in rather than captured: a captured value can't be sent on. #}
            func openExistential<\(staticGenericParameter): {{ container.name }}{{ container.genericPrimaryAssociatedTypeArguments }}>(_ opened: \(staticGenericParameter){% for declaration in method.sendingParameterDeclarations %}, {{ declaration }}{% endfor %}) {% if method.isAsync %} async{% endif %} {% if method.isThrowing %} throws{% endif %} -> {{ method.returnType }} {
                return {% if method.isThrowing %} try{% endif %} {% if method.isAsync %} await{% endif %} opened.{{ method.name }}{{ method.staticGenericCall }}
            }
            return {% if method.isThrowing %} try{% endif %} {% if method.isAsync %} await{% endif %} openExistential(reference(){% for name in method.sendingParameterNames %}, {{ name }}{% endfor %})
            {% elif method.hasGenericParams %}
            return {% if method.isThrowing %} try{% endif %} {% if method.isAsync %} await{% endif %} reference().{{ method.name }}({{ method.call }})
            {% else %}
            return {% if method.isThrowing %} try{% endif %} {% if method.isAsync %} await{% endif %} _storage${{ forloop.counter }}${{ method.name }}({{ method.parameterNames }})
            {% endif %}
        }
        {% if method.hasCompilationCondition %}
        #endif
        {% endif %}
        {% endfor %}
    }
    """
}
