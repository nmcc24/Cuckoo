struct MethodParameter: Token {
    var parent: Reference<any Token>?

    var name: String
    // FIXME: Is this needed?
    var innerName: String?
    var type: ComplexType
    
    var isInout: Bool {
        type.containsAttribute(named: "inout")
    }

    var nameAndInnerName: String {
        [name, innerName].compactMap { $0 }.joined(separator: " ")
    }

    var usableName: String {
        innerName ?? name
    }

    var description: String {
        "\(nameAndInnerName): \(type)"
    }

    var isSending: Bool {
        type.containsAttribute(named: "sending")
    }

    var isEscaping: Bool {
        type.isClosure && (type.containsAttribute(named: "@escaping") || type.isOptional)
    }
    
    var call: String {
        call(value: escapeReservedKeywords(for: usableName))
    }

    /// Like `call`, but a `sending` argument is read from the `Cuckoo.__SendingArgument`
    /// the mock wraps it in, because the mock has already recorded it.
    var forwardingCall: String {
        isSending ? call(value: "__\(usableName).value") : call
    }

    private func call(value name: String) -> String {
        let value = "\(isInout ? "&" : "")\(name)\(type.containsAttribute(named: "@autoclosure") ? "()" : "")"
        if self.name == "_" {
            return value
        } else {
            return "\(self.name): \(value)"
        }
    }
    
    /// The parameter as the mock manager records it. An opaque `some P` value is
    /// upcast to `any P`, the type its stubbing and verification matchers use;
    /// otherwise a stub's or recorded call's type wouldn't match the concrete argument type.
    var recordedValue: String {
        let name = escapeReservedKeywords(for: usableName)
        let matchedType = type.withoutAttributes(except: ["@MainActor", "@Sendable"])
        let genericSafeType = matchedType.genericArgumentSafe
        return genericSafeType == matchedType ? name : "\(name) as \(genericSafeType)"
    }

    func callAndCastTypes(named typeNames: [String], as replacement: (String) -> String) -> String {
        let replaced = type.replaceTypes(named: typeNames, with: replacement)
        
        let callToCast = call
        if let replaced {
            return callToCast.forceCast(as: replaced)
        } else {
            return callToCast
        }
    }

    func serialize() -> [String: Any] {
        return [
            "name": name,
            "innerName": innerName ?? "",
            "type": type,
            "nameAndInnerName": nameAndInnerName,
            "typeWithoutAttributes": type.withoutAttributes(),
            "isClosure": type.isClosure,
            "isOptional": type.isOptional,
            "isEscaping": isEscaping
        ]
    }
}
