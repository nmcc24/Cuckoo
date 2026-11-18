struct MethodParameter: Token {
    var parent: Reference<any Token>?

    var name: String
    /// The name the mock gives the parameter, `p0`, `p1` and so on, so a label that's a keyword or repeats another
    /// parameter's name still works in the mock's body. `nil` as crawled.
    var innerName: String?
    var type: ComplexType
    /// A `~Copyable` argument, which the mock records as a `Cuckoo.NoncopyableArgument`.
    var isNoncopyable = false
    /// A variadic parameter's element type, as in `Int...`. `type` is then the array the function receives,
    /// `[Int]`, which the mock records and its matchers take.
    var variadicElement: ComplexType? = nil
    /// The default value, as written: a class mock's override repeats it, or a call through the mock's type would
    /// have to pass the argument.
    var defaultValue: String? = nil
    /// A subscript's key, whose lone name is a parameter name, not a label.
    var isSubscriptKey = false

    var isVariadic: Bool {
        variadicElement != nil
    }

    var isInout: Bool {
        type.containsAttribute(named: "inout")
    }

    /// The label and the parameter name, or the label alone when they're the same: a label that's literally `p0`,
    /// the name the mock gives the first parameter, would otherwise read `p0 p0`, which warns. A subscript's key
    /// keeps both, since a lone name there isn't a label.
    var nameAndInnerName: String {
        guard let innerName, innerName != name || isSubscriptKey else { return name }
        return "\(name) \(innerName)"
    }

    var usableName: String {
        innerName ?? name
    }

    /// The parameter as an override declares it, with its default value.
    var declarationDescription: String {
        description + (defaultValue.map { " = \($0)" } ?? "")
    }

    var description: String {
        if let variadicElement {
            "\(nameAndInnerName): \(variadicElement)..."
        } else {
            "\(nameAndInnerName): \(type)"
        }
    }

    /// A label as a call writes it: a keyword label is escaped in a declaration, `` `in` ``, but not in a call,
    /// where escaping it warns, except `inout`, `var` and `let`, which a call still has to escape.
    static func argumentLabel(_ label: String) -> String {
        guard label.hasPrefix("`"), label.hasSuffix("`"), label.count > 2 else { return label }
        let bare = String(label.dropFirst().dropLast())
        return ["inout", "var", "let"].contains(bare) ? label : bare
    }

    var isSending: Bool {
        type.containsAttribute(named: "sending")
    }

    /// A copyable `consuming`, `borrowing` or `__owned` parameter, which Swift doesn't copy implicitly: the mock
    /// uses it several times (recorded, forwarded), so each use is an explicit `copy`.
    var needsExplicitCopy: Bool {
        !isNoncopyable && ["consuming", "borrowing", "__owned"].contains { type.containsAttribute(named: $0) }
    }

    /// A parameter pack, `repeat each T`.
    var isPack: Bool {
        type.withoutAttributes().description.hasPrefix("repeat ")
    }

    var call: String {
        call(value: escapeReservedKeywords(for: usableName))
    }

    /// Like `call`, but a `sending` argument is read from the `Cuckoo.__SendingArgument`
    /// the mock wraps it in, because the mock has already recorded it.
    var forwardingCall: String {
        // `copy` takes a variable; reading the wrapper's `value` gives a copy already.
        isSending ? call(value: "__\(usableName).value", copies: false) : call
    }

    private func call(value name: String, copies: Bool = true) -> String {
        let copy = needsExplicitCopy && copies ? "copy " : ""
        let value = isPack ? "repeat each \(name)" : "\(isInout ? "&" : "")\(copy)\(name)\(type.containsAttribute(named: "@autoclosure") ? "()" : "")"
        if self.name == "_" {
            return value
        } else {
            return "\(Self.argumentLabel(self.name)): \(value)"
        }
    }
    
    /// The parameter as the mock manager records it. An opaque `some P` value is
    /// upcast to `any P`, the type its stubbing and verification matchers use;
    /// otherwise a stub's or recorded call's type wouldn't match the concrete argument type.
    /// A parameter pack is recorded as one `Cuckoo.ParameterPack`.
    /// A `~Copyable` argument is recorded as a `Cuckoo.NoncopyableArgument` naming its type.
    var recordedValue: String {
        let name = escapeReservedKeywords(for: usableName)
        if isPack {
            return "Cuckoo.ParameterPack(repeat each \(name))"
        }
        if isNoncopyable {
            return "Cuckoo.NoncopyableArgument(type: \"\(type.withoutAttributes().genericArgumentSafe.description.trimmed)\")"
        }
        let genericSafeType = matchedType.genericArgumentSafe
        let value = needsExplicitCopy ? "(copy \(name))" : name
        return genericSafeType == matchedType ? value : "\(value) as \(genericSafeType)"
    }

    /// The type stubs and matchers take for the parameter: the recorded value's type.
    var matchedType: ComplexType {
        isNoncopyable ? .type("Cuckoo.NoncopyableArgument") : type.withoutAttributes(except: ["@MainActor", "@Sendable"])
    }

    func callAndCastTypes(named typeNames: [String], as replacement: (String) -> String) -> String {
        let replaced = type.replaceTypes(named: typeNames, with: replacement)
        if replaced != nil, let adapter = closureAdapter(named: typeNames, as: replacement) {
            return adapter
        }

        let callToCast = call
        if let replaced {
            return callToCast.forceCast(as: replaced)
        } else {
            return callToCast
        }
    }


    /// A non-escaping closure over associated types, passed as a closure taking the opened types: casting the
    /// closure itself always fails, as Swift can't convert a non-escaping function's type. The adapter casts each
    /// argument, and the result, instead. Nil for a closure it can't adapt, which is cast as before.
    private func closureAdapter(named typeNames: [String], as replacement: (String) -> String) -> String? {
        let allowedAttributes: Set = ["@Sendable", "@MainActor"]
        var attributes: [String] = []
        var base = type
        if case .attributed(let attributeList, let baseType) = type {
            guard attributeList.allSatisfy(allowedAttributes.contains) else { return nil }
            attributes = attributeList
            base = baseType
        }
        guard case .closure(let closure) = base,
              closure.parameters.allSatisfy({ !$0.type.containsAttribute(named: "inout") && !$0.type.description.hasSuffix("...") })
        else { return nil }
        let parameters = closure.parameters.enumerated().map { index, parameter in
            "__a\(index): \((parameter.type.replaceTypes(named: typeNames, with: replacement) ?? parameter.type).description)"
        }
        let arguments = closure.parameters.enumerated().map { index, parameter in
            parameter.type.containsTypes(named: typeNames) ? "__a\(index)".forceCast(as: parameter.type) : "__a\(index)"
        }
        let effects = closure.effects.description
        let tryAwait = (closure.effects.throwsClause != nil ? "try " : "") + (closure.effects.isAsync ? "await " : "")
        var call = "\(tryAwait)\(escapeReservedKeywords(for: usableName))(\(arguments.joined(separator: ", ")))"
        if let returned = closure.returnType.replaceTypes(named: typeNames, with: replacement) {
            call = "(\(call))".forceCast(as: returned)
        }
        let leading = attributes.isEmpty ? "" : attributes.joined(separator: " ") + " "
        let adapter = "{ \(leading)(\(parameters.joined(separator: ", ")))\(effects.isEmpty ? "" : " \(effects)") in \(call) }"
        return name == "_" ? adapter : "\(Self.argumentLabel(name)): \(adapter)"
    }

}
