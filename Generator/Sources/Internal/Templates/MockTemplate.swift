import Foundation

extension Templates {
    static let staticGenericParameter = "_CUCKOO$$GENERIC"
    static let typeErasureClassName = "DefaultImplCaller"
    static let typeErasureGenericParameterPrefix = "\(staticGenericParameter)_"
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
{{ container.accessibility|withSpace }}{% if container.isNonisolatedProtocol %}nonisolated {%+ endif %}{% if container.isActor %}actor{% else %}final class{% endif %} {{ container.mockName }}{{ container.genericParameters }}:{% if container.isNSObjectProtocol %} NSObject,{% endif %} {{ container.name }}{% if container.isImplementation %}{{ container.genericArguments }}{% endif %},{% if not container.isActor %} nonisolated{% endif %}{% if container.isImplementation %} Cuckoo.ClassMock{% else %} Cuckoo.ProtocolMock{% endif %} {
    {% if container.isGeneric and not container.isImplementation and not container.hasOnlyPrimaryAssociatedTypes %}
    {{ container.accessibility|withSpace }}typealias MocksType = \(typeErasureClassName)
    {% elif container.isImplementation %}
    {{ container.accessibility|withSpace }}typealias MocksType = {{ container.name }}{{ container.genericArguments }}
    {% else %}
    {{ container.accessibility|withSpace }}typealias MocksType = any {{ container.name }}{{ container.genericArguments }}
    {% endif %}
    {{ container.accessibility|withSpace }}typealias Stubbing = __StubbingProxy_{{ container.name }}
    {{ container.accessibility|withSpace }}typealias Verification = __VerificationProxy_{{ container.name }}

    // Original typealiases
    {% for typealias in container.typealiases %}
    {{ container.accessibility|withSpace }}{{ typealias }}
    {% endfor %}

    {{ container.accessibility|withSpace }}nonisolated let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: {{ container.isImplementation }})

    {% if container.isGeneric and not container.isImplementation and not container.hasOnlyPrimaryAssociatedTypes %}
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

    {% for property in container.properties %}

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
    {{ property.accessibility|withSpace }}{% if property.isOverriding %}override {%+ endif %}var {{ property.name|escapeReservedKeywords }}: {{ property.type }} {
        get {%+ if property.isAsync %}async {%+ endif %}{% if property.isThrowing %}throws {%+ endif %}{
            return {%+ if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}cuckoo_manager.getter{% if property.isThrowing %}Throws{% endif %}(
                "{{ property.name }}",
                invoke: { (implementation: {{ property.getterImplementationType|genericSafe }}) in {%+ if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}implementation({{ property.getterImplementationArguments }}) },
                superclassCall: {%+ if container.isImplementation -%}
                    {% if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}super.{{ property.name }}
                    {%- else -%}
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    {%- endif -%},
                defaultCall: {%+ if container.isActor and not property.isAsync %}Cuckoo.MockManager.crashOnActorDefaultImplementationCall("{{ property.name }}"){% else %}{% if property.isThrowing %}try {%+ endif %}{% if property.isAsync %}await {%+ endif %}__defaultImplStub.value.{{property.name}}{% endif +%}
            )
        }
        {% ifnot property.isReadOnly %}
        set {
            cuckoo_manager.setter(
                "{{ property.name }}",
                value: newValue,
                invoke: { (implementation: {{ property.setterImplementationType|genericSafe }}) in implementation({{ property.setterImplementationArguments }}) },
                superclassCall: {%+ if container.isImplementation -%}
                    super.{{ property.name }} = newValue
                    {%- else -%}
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    {%- endif -%},
                defaultCall: {%+ if container.isActor %}Cuckoo.MockManager.crashOnActorDefaultImplementationCall("{{ property.name }}"){% else %}__defaultImplStub.value.{{property.name}} = newValue{% endif +%}
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
    {% for method in container.methods %}

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
    {{ method.accessibility|withSpace }}{% if method.isOverriding %}override {%+ endif %}func {{ method.name|escapeReservedKeywords }}{{ method.signature }} {
        {% for name in method.sendingParameterNames %}
        let __{{ name }} = Cuckoo.__SendingArgument({{ name }})
        {% endfor %}
        {{ method.self|openNestedClosure }}return{% if method.isThrowing %} try{% endif %}{% if method.isAsync %} await{% endif %} {%+ if method.returnsSending %}Cuckoo.__SendingArgument({% endif %}cuckoo_manager.call{% if method.isThrowing %}{{ method.throwType|capitalize }}{% endif %}(
            "{{method.fullyQualifiedName}}",
            parameters: ({{method.recordedParameters}}),
            escapingParameters: ({{method.escapingParameterNames}}),
            {% if method.throwsOnly %}
            errorType: ({{ method.throwTypeError }}).self,
            {% endif %}
            invoke: { (implementation: {{ method.implementationType|genericSafe }}) {%+ if method.throwsOnly %}{% if method.isAsync %}async {%+ endif %}throws({{ method.throwTypeError }}) {%+ endif %}in {%+ if method.hasTypedThrows %}do { return try {%+ if method.isAsync %}await {%+ endif %}implementation({{ method.implementationArguments }}) } catch { throw Cuckoo.MockManager.typedError(error, as: ({{ method.throwTypeError }}).self, member: "{{ method.fullyQualifiedName }}") }{% else %}{% if method.isThrowing %}try {%+ endif %}{% if method.isAsync %}await {%+ endif %}implementation({{ method.implementationArguments }}){% endif %} },
            superclassCall: {%+ if container.isImplementation %}{% if method.isAsync %}await {%+ endif %}super.{{method.name}}({{method.forwardingCall}}){% else %}Cuckoo.MockManager.crashOnProtocolSuperclassCall(){% endif %},
            defaultCall: {%+ if container.isActor and not method.isAsync %}Cuckoo.MockManager.crashOnActorDefaultImplementationCall("{{ method.fullyQualifiedName }}"){% else %}{% if method.isAsync %}await {%+ endif %}__defaultImplStub.value.{{method.name}}{%if method.isOptional %}!{%endif%}({{method.forwardingCall}}){% endif +%}
        ){% if method.returnsSending %}).value{% endif %}{{ method.parameters|closeNestedClosure }}
    }
    {% if method.hasCompilationCondition %}
    #endif
    {% endif %}
    {% endfor %}

\(Templates.stubbingProxy.indented())

\(Templates.verificationProxy.indented())
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
