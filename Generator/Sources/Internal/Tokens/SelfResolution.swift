import Foundation

/// A protocol's mock and stub are `final` classes, where `Self` means the class itself but can only be written as
/// a method's or property's result. Their members name `Self` through a typealias each class declares to itself,
/// so `Self` can stand anywhere: as a parameter, inside an array, or in a closure.
enum SelfResolution {
    static let typealiasName = "__CuckooSelf"
}

extension ComplexType {
    /// Whether the type names `Self`.
    var mentionsSelf: Bool {
        description.range(of: #"\bSelf\b"#, options: .regularExpression) != nil
    }

    /// The type with `Self` replaced by `name`, except where it's qualified, as in `Self.Element`.
    func resolvingSelf(as name: String) -> ComplexType {
        switch self {
        case .attributed(let attributes, let baseType):
            .attributed(attributes: attributes, baseType: baseType.resolvingSelf(as: name))
        case .optional(let wrappedType, let isImplicit):
            .optional(wrappedType: wrappedType.resolvingSelf(as: name), isImplicit: isImplicit)
        case .array(let elementType):
            .array(elementType: elementType.resolvingSelf(as: name))
        case .dictionary(let keyType, let valueType):
            .dictionary(keyType: keyType.resolvingSelf(as: name), valueType: valueType.resolvingSelf(as: name))
        case .closure(let closure):
            .closure(
                Closure(
                    parameters: closure.parameters.map { .init(label: $0.label, type: $0.type.resolvingSelf(as: name)) },
                    effects: closure.effects,
                    returnType: closure.returnType.resolvingSelf(as: name)
                )
            )
        case .type(let typeName):
            .type(typeName.replacingOccurrences(of: #"\bSelf\b(?!\.)"#, with: name, options: .regularExpression))
        }
    }
}

extension Token {
    /// The token with its members' `Self` resolved: a protocol's to ``SelfResolution/typealiasName``, unless it's
    /// an `Actor` protocol, whose mock is an actor and can write `Self` anywhere. Members that take or return `Self`
    /// are marked either way, because they can't be forwarded to a default implementation, whose `Self` isn't the mock.
    func resolvingSelf() -> any Token {
        switch self {
        case let protocolDeclaration as ProtocolDeclaration:
            let name = protocolDeclaration.isActor ? nil : SelfResolution.typealiasName
            return protocolDeclaration.replacing(members: protocolDeclaration.members.map { $0.resolvingSelfInMember(as: name) })
        case let classDeclaration as ClassDeclaration:
            return classDeclaration.replacing(members: classDeclaration.members.map { $0.resolvingSelfInMember(as: nil) })
        default:
            return self
        }
    }

    /// A member with `Self` replaced by `name`, or only marked when `name` is `nil`.
    private func resolvingSelfInMember(as name: String?) -> any Token {
        switch self {
        case var method as Method:
            let signature = method.signature
            guard (signature.parameters.map(\.type) + [signature.returnType].compactMap { $0 }).contains(where: \.mentionsSelf) else {
                return method
            }
            method.mentionsSelf = true
            if let name {
                // Calls stay recorded, and named in failures, as written.
                method.recordedName = method.fullyQualifiedName
                method.signature = Method.Signature(
                    genericParameters: signature.genericParameters,
                    parameters: signature.parameters.map { parameter in
                        var parameter = parameter
                        parameter.type = parameter.type.resolvingSelf(as: name)
                        return parameter
                    },
                    asyncType: signature.asyncType,
                    throwType: signature.throwType,
                    returnType: signature.returnType?.resolvingSelf(as: name),
                    whereConstraints: signature.whereConstraints
                )
            }
            return method
        case var variable as Variable:
            guard variable.type.mentionsSelf else { return variable }
            variable.mentionsSelf = true
            if let name {
                variable.type = variable.type.resolvingSelf(as: name)
            }
            return variable
        case var subscriptToken as Subscript:
            guard (subscriptToken.parameters.map(\.type) + [subscriptToken.returnType]).contains(where: \.mentionsSelf) else {
                return subscriptToken
            }
            subscriptToken.mentionsSelf = true
            if let name {
                subscriptToken.recordedSignature = subscriptToken.signature
                subscriptToken.parameters = subscriptToken.parameters.map { parameter in
                    var parameter = parameter
                    parameter.type = parameter.type.resolvingSelf(as: name)
                    return parameter
                }
                subscriptToken.returnType = subscriptToken.returnType.resolvingSelf(as: name)
            }
            return subscriptToken
        default:
            return self
        }
    }
}
