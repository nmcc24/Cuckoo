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
{% for attribute in container.spiAttributes %}
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
    {{ container.typeErasure }}

    nonisolated private let __defaultImplStub = Cuckoo.DefaultImplementation<\(typeErasureClassName)>()
    {% if container.globalActor %}

    {# For developers: `Mock`'s requirement. Wrapping a default implementation reads it on the global actor, so the
    generic overloads below are isolated to it. #}
    {{ container.accessibility|withSpace }}nonisolated func enableDefaultImplementation(_ stub: \(typeErasureClassName)) {
        __defaultImplStub.value = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    {% endif %}

    {{ container.globalActorAttribute }}{{ container.accessibility|withSpace }}{% if not container.globalActor %}nonisolated {%+ endif %}func enableDefaultImplementation<\(staticGenericParameter): {{ container.name }}{% if not container.globalActor %} & SendableMetatype{% endif %}>(_ stub: \(staticGenericParameter)) where {{ container.genericProtocolIdentity }}{% if not container.globalActor %}{{ container.sendableMetatypeRequirements }}{% endif %} {
        __defaultImplStub.value = \(typeErasureClassName)(stub)
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

    {{ container.mockMembers }}

    {{ container.stubbingProxy }}

    {{ container.verificationProxy }}
    {% if container.hasStaticMembers %}

    {{ container.staticStubbingProxy }}

    {{ container.staticVerificationProxy }}
    {% endif %}
}

{{ container.nopImplStub }}

{% if container.hasParent %}
}
{% endif %}
{% if container.hasEnclosingCompilationCondition %}
#endif
{% endif %}

{% endfor %}
"""
}
