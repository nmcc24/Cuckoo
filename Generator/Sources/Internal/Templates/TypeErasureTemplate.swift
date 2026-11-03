import Foundation

extension Templates {
    static let typeErasure = """
    {# For developers: the caller erases the default implementation's type. Its closures share one
    `Cuckoo.DefaultImplementation` box, which is `Sendable`, so the closures are `@Sendable` and the caller is
    checked `Sendable`, as a mock of a `Sendable` generic protocol needs. A protocol isolated to a global actor
    gets a caller isolated to it, which is `Sendable` and can read the requirements. #}
    {% if container.globalActor %}
    @{{ container.globalActor }} {{ container.accessibility|withSpace }}final class \(typeErasureClassName): {{ container.name }} {
    {% else %}
    {{ container.accessibility|withSpace }}nonisolated final class \(typeErasureClassName): {{ container.name }}, Sendable {
    {% endif %}
        {% if container.declaresSelfTypealias %}
        {{ container.accessibility|withSpace }}typealias \(SelfResolution.typealiasName) = \(typeErasureClassName)
        {% endif %}
        private let reference: {%+ if not container.globalActor %}@Sendable {%+ endif %}() -> any {{ container.name }}{{ container.genericPrimaryAssociatedTypeArguments }}

        {% for property in container.properties %}
        {% if property.hasCompilationCondition %}
        {{ property.compilationConditionCheck }}
        {% endif %}
        private let _getter_storage$${{ property.name }}: {%+ if not container.globalActor %}@Sendable {%+ endif %}() -> {{ property.type }}
        {% if not property.isReadOnly %}
        private let _setter_storage$${{ property.name }}: {%+ if not container.globalActor %}@Sendable {%+ endif %}({{ property.type }}) -> Void
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
        private let _subscript_getter_storage$${{ forloop.counter }}: {%+ if not container.globalActor %}@Sendable {%+ endif %}({{ subscript.keyTypes }}) {%+ if subscript.getterEffects %}{{ subscript.getterEffects }}{% endif %}-> {{ subscript.returnType }}
        {% if not subscript.isReadOnly %}
        private let _subscript_setter_storage$${{ forloop.counter }}: {%+ if not container.globalActor %}@Sendable {%+ endif %}({{ subscript.keyTypes }}{% if subscript.keyTypes %}, {% endif %}{{ subscript.returnType }}) -> Void
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
        {# For developers: every closure reads the default implementation from the box when it runs, and a
        mutating requirement writes it back, so a value-type default implementation keeps its changes. #}
        init<\(staticGenericParameter): {{ container.name }}{% if not container.globalActor %} & SendableMetatype{% endif %}>(_ defaultImpl: \(staticGenericParameter)) where {{ container.genericProtocolIdentity }}{% if not container.globalActor %}{{ container.sendableMetatypeRequirements }}{% endif %} {
            let box = Cuckoo.DefaultImplementation<\(staticGenericParameter)>()
            box.value = defaultImpl
            reference = { box.value }

            {% for property in container.properties %}
            {% if property.hasCompilationCondition %}
            {{ property.compilationConditionCheck }}
            {% endif %}
            _getter_storage$${{ property.name }} = { box.value.{{ property.name }} }
            {% if not property.isReadOnly %}
            _setter_storage$${{ property.name }} = { box.value.{{ property.name }} = $0 }
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
            _subscript_getter_storage$${{ forloop.counter }} = { {%+ if subscript.isThrowing %}try {%+ endif %}{% if subscript.isAsync %}await {%+ endif %}box.value[{{ subscript.keyClosureParameters }}] }
            {% if not subscript.isReadOnly %}
            _subscript_setter_storage$${{ forloop.counter }} = { box.value[{{ subscript.keyClosureParameters }}] = ${{ subscript.keyCount }} }
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
            _storage${{ forloop.counter }}${{ method.name }} = { {%+ if method.parameterNames %}{{ method.parameterNames }} in {%+ endif %}{% if method.isThrowing %}try {%+ endif %}{% if method.isAsync %}await {%+ endif %}box.value.{{ method.name|escapeReservedKeywords }}({{ method.call }}) }
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
        private let _storage${{ forloop.counter }}${{ method.name }}: {%+ if not container.globalActor %}@Sendable {%+ endif %}({{ method.inputTypes }}) {% if method.isAsync %} async{% endif %} {% if method.isThrowing %} throws{% endif %} -> {{ method.returnType }}
        {% endif %}
        {% for attribute in method.spiAttributes %}
        {{ attribute }}
        {% endfor %}
        {{ container.accessibility|withSpace }}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
            {% if method.hasGenericParams and method.usesNonPrimaryAssociatedTypes %}
            {# A `sending` argument is passed in rather than captured: a captured value can't be sent on. #}
            {% for variant in method.localFunctionVariants %}
            {% if variant.directive %}
            {{ variant.directive }}
            {% endif %}
            {{ variant.modifier }}func openExistential<\(staticGenericParameter): {{ container.name }}{{ container.genericPrimaryAssociatedTypeArguments }}>(_ opened: \(staticGenericParameter){% for declaration in method.sendingParameterDeclarations %}, {{ declaration }}{% endfor %}) {% if method.isAsync %} async{% endif %} {% if method.isThrowing %} throws{% endif %} -> {{ method.returnType }} {
                return {% if method.isThrowing %} try{% endif %} {% if method.isAsync %} await{% endif %} opened.{{ method.name }}{{ method.staticGenericCall }}
            }
            {% endfor %}
            {% if method.localFunctionVariantsAreConditional %}
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
