import Foundation

extension Templates {
    static let staticGenericParameter = "_CUCKOO$$GENERIC"
    static let typeErasureClassName = "DefaultImplCaller"
    static let typeErasureGenericParameterPrefix = "\(staticGenericParameter)_"
    /// The body of a mocked method or subscript accessor, `method`: it records the call and runs the stub.
    static let methodBody = """
{% for name in method.sendingParameterNames %}
let __{{ name }} = Cuckoo.__SendingArgument({{ name }})
{% endfor %}
{{ method.self|openNestedClosure }}return{% if method.isThrowing %} try{% endif %}{% if method.isAsync %} await{% endif %} {%+ if method.returnsSending %}Cuckoo.__SendingArgument({% endif %}{{ method.manager }}.call{% if method.isThrowing %}{{ method.throwType|capitalize }}{% endif %}(
    "{{method.fullyQualifiedName}}",
    parameters: ({{method.recordedParameters}}),
    escapingParameters: ({{method.escapingParameterNames}}),
    {% if method.throwsOnly %}
    errorType: ({{ method.throwTypeError }}).self,
    {% endif %}
    invoke: { (implementation: {{ method.implementationType|genericSafe }}, arguments) {%+ if method.throwsOnly %}{% if method.isAsync %}async {%+ endif %}throws({{ method.throwTypeError }}) {%+ endif %}in {%+ if method.inoutPrologue %}{{ method.inoutPrologue }} {%+ endif %}{% if method.hasTypedThrows %}do { return try {%+ if method.isAsync %}await {%+ endif %}implementation({{ method.implementationArguments }}) } catch { throw Cuckoo.MockManager.typedError(error, as: ({{ method.throwTypeError }}).self, member: "{{ method.fullyQualifiedName }}") }{% else %}{% if method.inoutPrologue %}return {%+ endif %}{% if method.isThrowing %}try {%+ endif %}{% if method.isAsync %}await {%+ endif %}implementation({{ method.implementationArguments }}){% endif %} },
    superclassCall: {%+ if not container.isImplementation %}Cuckoo.MockManager.crashOnProtocolSuperclassCall(){% elif method.hasNoncopyableParams %}Cuckoo.MockManager.crashOnNoncopyableArgumentForward("{{ method.fullyQualifiedName }}"){% else %}{% if method.isAsync %}await {%+ endif %}{{ method.superclassCall }}{% endif %},
    defaultCall: {%+ if container.isActor and not method.isStatic %}Cuckoo.MockManager.crashOnActorDefaultImplementationCall("{{ method.fullyQualifiedName }}"){% elif method.mentionsSelf and not method.isStatic %}Cuckoo.MockManager.crashOnSelfDefaultImplementationCall("{{ method.fullyQualifiedName }}"){% elif method.hasNoncopyableParams and not method.isStatic %}Cuckoo.MockManager.crashOnNoncopyableArgumentForward("{{ method.fullyQualifiedName }}"){% else %}{% if method.isAsync and not method.isStatic %}await {%+ endif %}{{ method.defaultCall }}{% endif +%}
){% if method.returnsSending %}).value{% endif %}{{ method.self|closeNestedClosure }}
"""

    static let mock = """
{% for container in containers %}
{% if container.hasEnclosingCompilationCondition %}
{{ container.enclosingCompilationConditionCheck }}
{% endif %}
{% if debug %}
// {{ container }}
{% endif %}
{% for attribute in container.attributes %}
{{ attribute }}
{% endfor %}
{% if container.hasParent %}
extension {{ container.parentFullyQualifiedName }} {
{% endif %}
{% if container.hasPrimaryAssociatedTypes %}
// runtime support for constrained protocols with primary associated types
@available(iOS 16, macOS 13, watchOS 9, tvOS 16, *)
{% endif %}
{{ container.accessibility|withSpace }}{% if container.isNonisolatedProtocol %}nonisolated {%+ endif %}{% if container.isActor %}actor{% else %}final class{% endif %} {{ container.mockName }}{{ container.genericParameters }}:{% if container.superclass %} {{ container.superclass }},{% endif %} {{ container.name }}{% if container.isImplementation %}{{ container.genericArguments }}{% endif %},{% if not container.isActor %} nonisolated{% endif %}{% if container.isImplementation %} Cuckoo.ClassMock{% else %} Cuckoo.ProtocolMock{% endif %}{% if container.hasStaticMembers %},{% if not container.isActor %} nonisolated{% endif %} Cuckoo.StaticMock{% endif %} {
    {% if container.isGeneric and not container.isImplementation and not container.hasOnlyPrimaryAssociatedTypes %}
    {{ container.accessibility|withSpace }}typealias MocksType = \(typeErasureClassName)
    {% elif container.isImplementation %}
    {{ container.accessibility|withSpace }}typealias MocksType = {{ container.name }}{{ container.genericArguments }}
    {% else %}
    {{ container.accessibility|withSpace }}typealias MocksType = any {{ container.name }}{{ container.genericArguments }}
    {% endif %}
    {{ container.accessibility|withSpace }}typealias Stubbing = __StubbingProxy_{{ container.name }}
    {{ container.accessibility|withSpace }}typealias Verification = __VerificationProxy_{{ container.name }}
    {% if container.declaresSelfTypealias %}
    {{ container.accessibility|withSpace }}typealias \(SelfResolution.typealiasName) = {{ container.mockName }}
    {% endif %}
    {% if container.hasStaticMembers %}
    {{ container.accessibility|withSpace }}typealias StaticStubbing = __StaticStubbingProxy_{{ container.name }}
    {{ container.accessibility|withSpace }}typealias StaticVerification = __StaticVerificationProxy_{{ container.name }}
    {% endif %}

    // Original typealiases
    {% for typealias in container.typealiases %}
    {{ container.accessibility|withSpace }}{{ typealias }}
    {% endfor %}

    {{ container.accessibility|withSpace }}nonisolated let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: {{ container.isImplementation }})

    {% if container.isActor %}
    {{ container.accessibility|withSpace }}nonisolated func enableDefaultImplementation(_ stub: MocksType) {
        cuckoo_manager.refuseActorDefaultImplementation()
    }
    {% elif container.isGeneric and not container.isImplementation and not container.hasOnlyPrimaryAssociatedTypes %}
\(Templates.typeErasure.indented())

    nonisolated private let __defaultImplStub = Cuckoo.DefaultImplementation<\(typeErasureClassName)>()

    {{ container.accessibility|withSpace }}nonisolated func enableDefaultImplementation<\(staticGenericParameter): {{ container.name }}>(_ stub: \(staticGenericParameter)) where {{ container.genericProtocolIdentity }} {
        var mutableStub = stub
        __defaultImplStub.value = \(typeErasureClassName)(from: &mutableStub, keeping: mutableStub)
        cuckoo_manager.enableDefaultStubImplementation()
    }

    {{ container.accessibility|withSpace }}nonisolated func enableDefaultImplementation<\(staticGenericParameter): {{ container.name }}>(mutating stub: UnsafeMutablePointer<\(staticGenericParameter)>) where {{ container.genericProtocolIdentity }} {
        __defaultImplStub.value = \(typeErasureClassName)(from: stub, keeping: stub.pointee)
        cuckoo_manager.enableDefaultStubImplementation()
    }
    {% else %}
    {% if container.isImplementation %}
    nonisolated private let __defaultImplStub = Cuckoo.DefaultImplementation<{{ container.name }}{{ container.genericArguments }}>()
    {% else %}
    nonisolated private let __defaultImplStub = Cuckoo.DefaultImplementation<any {{ container.name }}{{ container.genericArguments }}>()
    {% endif %}

    {{ container.accessibility|withSpace }}nonisolated func enableDefaultImplementation(_ stub: {%+ if not container.isImplementation %}any {%+ endif %}{{ container.name }}{{ container.genericArguments }}) {
        __defaultImplStub.value = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    {% endif -%}

    {% for property in container.allProperties %}

    {% if property.hasCompilationCondition %}
    {{ property.compilationConditionCheck }}
    {% endif %}
    {% if debug %}
    // {{ property }}
    {% endif %}
    {% if keepDocumentation %}
    {% for docString in property.documentation %}
    /// {{ docString }}
    {% endfor %}
    {% endif %}
    {% for attribute in property.attributes %}
    {{ attribute }}
    {% endfor %}
    {% if property.isolationAttribute %}
    {{ property.isolationAttribute }}
    {% endif %}
    {{ property.accessibility|withSpace }}{% if property.isOverriding %}override {%+ endif %}{{ property.staticKeyword }}var {{ property.name|escapeReservedKeywords }}: {{ property.type }} {
        get {%+ if property.isAsync %}async {%+ endif %}{% if property.isThrowing %}throws {%+ endif %}{
            return {%+ if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}{{ property.manager }}.getter{% if property.isThrowing %}Throws{% endif %}(
                "{{ property.name }}",
                invoke: { (implementation: {{ property.getterImplementationType|genericSafe }}) in {%+ if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}implementation({{ property.getterImplementationArguments }}) },
                superclassCall: {%+ if container.isImplementation -%}
                    {% if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}super.{{ property.name }}
                    {%- else -%}
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    {%- endif -%},
                defaultCall: {%+ if property.isStatic %}Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ property.name }}"){% elif container.isActor %}Cuckoo.MockManager.crashOnActorDefaultImplementationCall("{{ property.name }}"){% elif property.mentionsSelf %}Cuckoo.MockManager.crashOnSelfDefaultImplementationCall("{{ property.name }}"){% else %}{% if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}__defaultImplStub.value.{{property.name}}{% endif +%}
            )
        }
        {% ifnot property.isReadOnly %}
        set {
            {{ property.manager }}.setter(
                "{{ property.name }}",
                value: newValue,
                invoke: { (implementation: {{ property.setterImplementationType|genericSafe }}, value) in implementation({{ property.setterImplementationArguments }}) },
                superclassCall: {%+ if container.isImplementation -%}
                    super.{{ property.name }} = newValue
                    {%- else -%}
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    {%- endif -%},
                defaultCall: {%+ if property.isStatic %}Cuckoo.MockManager.crashOnStaticDefaultImplementationCall("{{ property.name }}"){% elif container.isActor %}Cuckoo.MockManager.crashOnActorDefaultImplementationCall("{{ property.name }}"){% elif property.mentionsSelf %}Cuckoo.MockManager.crashOnSelfDefaultImplementationCall("{{ property.name }}"){% else %}__defaultImplStub.value.{{property.name}} = newValue{% endif +%}
            )
        }
        {% endif %}
    }
    {% if property.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}

    {% for initializer in container.initializers %}
    {% if initializer.hasCompilationCondition %}
    {{ initializer.compilationConditionCheck }}
    {% endif %}
    {% if debug %}
    // {{ initializer }}
    {% endif %}
    {% if keepDocumentation %}
    {% for docString in initializer.documentation %}
    /// {{ docString }}
    {% endfor %}
    {% endif %}
    {{ initializer.accessibility|withSpace }}required init{{initializer.signature}} {}
    {% if initializer.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
    {% for method in container.allMethods %}

    {% if method.hasCompilationCondition %}
    {{ method.compilationConditionCheck }}
    {% endif %}
    {% if debug %}
    // {{method}}
    {% endif %}
    {% if keepDocumentation %}
    {% for docString in method.documentation %}
    /// {{ docString }}
    {% endfor %}
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
    {{ method.accessibility|withSpace }}{% if method.isOverriding %}override {%+ endif %}{{ method.staticKeyword }}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
\(Templates.methodBody.indented(times: 2))
    }
    {% if method.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}
    {% for subscript in container.allSubscripts %}

    {% if subscript.hasCompilationCondition %}
    {{ subscript.compilationConditionCheck }}
    {% endif %}
    {% if keepDocumentation %}
    {% for docString in subscript.documentation %}
    /// {{ docString }}
    {% endfor %}
    {% endif %}
    {% for attribute in subscript.attributes %}
    {{ attribute }}
    {% endfor %}
    {% if subscript.isolationAttribute %}
    {{ subscript.isolationAttribute }}
    {% endif %}
    {{ subscript.accessibility|withSpace }}{% if subscript.isOverriding %}override {%+ endif %}{{ subscript.staticKeyword }}subscript{{ subscript.signature }} {
        get {{ subscript.getterEffects }}{
            {% for method in subscript.getters %}
\(Templates.methodBody.indented(times: 3))
            {% endfor %}
        }
        {% for method in subscript.setters %}
        set({{ subscript.newValueName }}) {
\(Templates.methodBody.indented(times: 3))
        }
        {% endfor %}
    }
    {% if subscript.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}

\(Templates.stubbingProxy(isStatic: false).indented())

\(Templates.verificationProxy(isStatic: false).indented())
    {% if container.hasStaticMembers %}

\(Templates.stubbingProxy(isStatic: true).indented())

\(Templates.verificationProxy(isStatic: true).indented())
    {% endif %}
}

\(Templates.noImplStub)

{% if container.hasParent %}
}
{% endif %}
{% if container.hasEnclosingCompilationCondition %}
#endif
{% endif %}

{% endfor %}
"""
}
