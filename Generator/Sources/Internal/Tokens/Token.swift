protocol Token: Serializable {
    var parent: Reference<any Token>? { get set }
}

extension Token {
    func serialize() -> GeneratorContext {
        commonSerialize()
    }

    func commonSerialize() -> GeneratorContext {
        [
            [
                "@type": "\(type(of: self))",
                "isImplementation": isClass,
                "hasParent": parent != nil,
            ],
            (self as? any ContainerToken)?.containerSerialize(),
            (self as? any HasName)?.nameSerialize(),
            (parent?.value as? any HasName).map { ["parentFullyQualifiedName": $0.fullyQualifiedName] },
            (self as? any HasGenerics)?.genericsSerialize(),
            asProtocol.map {
                [
                    "superclass": $0.superclass ?? "",
                    "isActor": $0.isActor,
                    // Its mock and stub are explicitly `nonisolated`, so they don't take on the module's
                    // default isolation (`-default-isolation MainActor`). A subclass of a declared class
                    // takes on that class's isolation instead.
                    "isNonisolatedProtocol": !$0.isActor && $0.isolation == nil && !$0.isSuperclassDeclared,
                    // The global actor the protocol is isolated to, which its requirements take on.
                    "globalActor": $0.globalActor ?? "",
                    "globalActorAttribute": $0.globalActor.map { "@\($0) " } ?? "",
                ]
            },
            (self as? any HasInheritance)?.inheritanceSerialize(),
            (self as? any HasEnclosingCompilationConditions)?.enclosingCompilationConditionsSerialize(),
        ]
        .compactMap { $0 }
        .merge()
    }

    var isMockable: Bool {
        [isClass, isProtocol, isVariable, isMethod].contains(true)
    }

    var isVariable: Bool {
        self is Variable
    }

    var isMethod: Bool {
        self is Method
    }

    var isClass: Bool {
        self is ClassDeclaration
    }

    var asClass: ClassDeclaration? {
        self as? ClassDeclaration
    }

    var isProtocol: Bool {
        self is ProtocolDeclaration
    }

    var asProtocol: ProtocolDeclaration? {
        self as? ProtocolDeclaration
    }
}
