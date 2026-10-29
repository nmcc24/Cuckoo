import Foundation

extension Templates {
    static let typeErasure = """
    {# For developers: `@unchecked` because the stored closures read the default implementation through an
    `UnsafeMutablePointer`, which can't be checked `Sendable`. A mock of a `Sendable` generic protocol needs the
    conformance. Removing it needs the erasure rebuilt on a Sendable box (roadmap Phase 5). #}
    {{ container.accessibility|withSpace }}nonisolated final class \(typeErasureClassName): {{ container.name }}, @unchecked Sendable {
        {% if container.declaresSelfTypealias %}
        {{ container.accessibility|withSpace }}typealias \(SelfResolution.typealiasName) = \(typeErasureClassName)
        {% endif %}
        private let reference: () -> any {{ container.name }}{{ container.genericPrimaryAssociatedTypeArguments }}

        {% for property in container.properties %}
        {% if property.hasCompilationCondition %}
        {{ property.compilationConditionCheck }}
        {% endif %}
        private let _getter_storage$${{ property.name }}: () -> {{ property.type }}
        {% if not property.isReadOnly %}
        private let _setter_storage$${{ property.name }}: ({{ property.type }}) -> Void
        {% endif %}
        {% for attribute in property.spiAttributes %}
        {{ attribute }}
        {% endfor %}
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
        {% for subscript in container.subscripts %}
        {% if subscript.hasCompilationCondition %}
        {{ subscript.compilationConditionCheck }}
        {% endif %}
        {% if not subscript.hasGenericParams %}
        private let _subscript_getter_storage$${{ forloop.counter }}: ({{ subscript.keyTypes }}) {%+ if subscript.getterEffects %}{{ subscript.getterEffects }}{% endif %}-> {{ subscript.returnType }}
        {% if not subscript.isReadOnly %}
        private let _subscript_setter_storage$${{ forloop.counter }}: ({{ subscript.keyTypes }}{% if subscript.keyTypes %}, {% endif %}{{ subscript.returnType }}) -> Void
        {% endif %}
        {% endif %}
        {% for attribute in subscript.spiAttributes %}
        {{ attribute }}
        {% endfor %}
        {{ container.accessibility|withSpace }}subscript{{ subscript.signature }} {
            get {{ subscript.getterEffects }}{
                {% if subscript.hasGenericParams %}
                return {% if subscript.isThrowing %}try {%+ endif %}{% if subscript.isAsync %}await {%+ endif %}reference()[{{ subscript.getter.forwardingCall }}]
                {% else %}
                return {% if subscript.isThrowing %}try {%+ endif %}{% if subscript.isAsync %}await {%+ endif %}_subscript_getter_storage$${{ forloop.counter }}({{ subscript.getter.parameterNames }})
                {% endif %}
            }
            {% if not subscript.isReadOnly %}
            set {
                {% if subscript.hasGenericParams %}
                var reference = reference()
                reference[{{ subscript.getter.forwardingCall }}] = newValue
                {% else %}
                _subscript_setter_storage$${{ forloop.counter }}({{ subscript.getter.parameterNames }}{% if subscript.keyTypes %}, {% endif %}newValue)
                {% endif %}
            }
            {% endif %}
        }
        {% if subscript.hasCompilationCondition %}
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
            {% for subscript in container.subscripts %}
            {% if not subscript.hasGenericParams %}
            {% if subscript.hasCompilationCondition %}
            {{ subscript.compilationConditionCheck }}
            {% endif %}
            _subscript_getter_storage$${{ forloop.counter }} = { {%+ if subscript.isThrowing %}try {%+ endif %}{% if subscript.isAsync %}await {%+ endif %}defaultImpl.pointee[{{ subscript.keyClosureParameters }}] }
            {% if not subscript.isReadOnly %}
            _subscript_setter_storage$${{ forloop.counter }} = { defaultImpl.pointee[{{ subscript.keyClosureParameters }}] = ${{ subscript.keyCount }} }
            {% endif %}
            {% if subscript.hasCompilationCondition %}
            #endif
            {% endif %}
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
        {% for attribute in initializer.spiAttributes %}
        {{ attribute }}
        {% endfor %}
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
        {% for attribute in method.spiAttributes %}
        {{ attribute }}
        {% endfor %}
        {{ container.accessibility|withSpace }}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
            {% if method.hasGenericParams and method.hasNonPrimaryAssociatedTypeParams %}
            {# A `sending` argument is passed in rather than captured: a captured value can't be sent on. #}
            {% for variant in method.localFunctionVariants %}
            {% if variant.directive %}
            {{ variant.directive }}
            {% endif %}
            {{ variant.modifier }}func openExistential<\(staticGenericParameter): {{ container.name }}{{ container.genericPrimaryAssociatedTypeArguments }}>(_ opened: \(staticGenericParameter){% for declaration in method.sendingParameterDeclarations %}, {{ declaration }}{% endfor %}) {% if method.isAsync %} async{% endif %} {% if method.isThrowing %} throws{% endif %} -> {{ method.returnType }} {
                return {% if method.isThrowing %} try{% endif %} {% if method.isAsync %} await{% endif %} opened.{{ method.name }}{{ method.staticGenericCall }}
            }
            {% endfor %}
            {% if method.isAsync %}
            #endif
            {% endif %}
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
        {% for property in container.staticProperties %}

        {% if property.hasCompilationCondition %}
        {{ property.compilationConditionCheck }}
        {% endif %}
        {% for attribute in property.spiAttributes %}
        {{ attribute }}
        {% endfor %}
        {{ container.accessibility|withSpace }}static var {{ property.name }}: {{ property.type }} {
            get {%+ if property.isAsync %}async {%+ endif %}{% if property.isThrowing %}throws {%+ endif %}{ Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ property.name }}") }
            {% if not property.isReadOnly %}
            set { Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ property.name }}") as Void }
            {% endif %}
        }
        {% if property.hasCompilationCondition %}
        #endif
        {% endif %}
        {% endfor %}
        {% for method in container.staticMethods %}

        {% if method.hasCompilationCondition %}
        {{ method.compilationConditionCheck }}
        {% endif %}
        {% for attribute in method.spiAttributes %}
        {{ attribute }}
        {% endfor %}
        {{ container.accessibility|withSpace }}static func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
            Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ method.fullyQualifiedName }}")
        }
        {% if method.hasCompilationCondition %}
        #endif
        {% endif %}
        {% endfor %}
        {% for subscript in container.staticSubscripts %}

        {% if subscript.hasCompilationCondition %}
        {{ subscript.compilationConditionCheck }}
        {% endif %}
        {% for attribute in subscript.spiAttributes %}
        {{ attribute }}
        {% endfor %}
        {{ container.accessibility|withSpace }}static subscript{{ subscript.signature }} {
            get {{ subscript.getterEffects }}{ Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ subscript.getter.fullyQualifiedName }}") }
            {% if not subscript.isReadOnly %}
            set { Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ subscript.setter.fullyQualifiedName }}") as Void }
            {% endif %}
        }
        {% if subscript.hasCompilationCondition %}
        #endif
        {% endif %}
        {% endfor %}
    }
    """
}
