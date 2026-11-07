protocol Token {
    var parent: Reference<any Token>? { get set }
}

extension Token {
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
