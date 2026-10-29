import Foundation

struct Method: Token, HasAttributes, HasAccessibility, HasName {
    var parent: Reference<any Token>?

    var documentation: [String]
    var attributes: [Attribute]
    var accessibility: Accessibility
    var name: String
    var signature: Signature
    var isOptional: Bool
    /// The `#if` conditions the declaration is nested in.
    var compilationConditions: [String] = []
    /// The member's own isolation, if it states one.
    var isolation: Isolation?
    /// `nonisolated(nonsending)` or `@concurrent`: where an async member runs. Mocks keep it.
    var executionAttribute: String?
    /// The name the mock manager records the call under, when it isn't the method's own (a subscript's accessors).
    var recordedName: String?
    /// A `static` or `class` member, recorded by the mock type's static manager.
    var isStatic = false
    /// Whether a parameter or the result names `Self`; see ``Token/resolvingSelf()``.
    var mentionsSelf = false

    var fullSignature: String {
        [
            accessibility.sourceName,
            "\(name)\(signature.description)",
        ]
        .compactMap { $0.nilIfEmpty }
        .joined(separator: " ")
    }
}

extension Method: Inheritable {
    func isEqual(to other: any Inheritable) -> Bool {
        guard let other = other as? Method else { return false }
        return name == other.name && isStatic == other.isStatic && signature.isApiEqual(to: other.signature)
    }
}

extension Method {
    var fullyQualifiedName: String {
        recordedName ?? "\(isStatic ? "static " : "")\(name)\(signature.description.trimmed)"
    }
    
    var isAsync: Bool {
        signature.asyncType.map { $0.isAsync || $0.isReasync } ?? false
    }
    
    var isThrowing: Bool {
        signature.throwType.map { $0.isThrowing || $0.isRethrowing } ?? false
    }
    
    var throwsOnly: Bool {
        signature.throwType.map { $0.isThrowing } ?? false
    }

    var returnType: ComplexType? {
        signature.returnType
    }

    var hasClosureParams: Bool {
        signature.parameters.contains { $0.type.isClosure }
    }

    var hasOptionalParams: Bool {
        signature.parameters.contains { $0.type.isOptional }
    }
    
    /// The isolation the stubs take. An actor's static members aren't isolated to an instance.
    var stubbedIsolation: Isolation? {
        if isStatic && isolation == nil && parent?.value.asProtocol?.isActor == true {
            return .nonisolated
        }
        return isolation
    }

    /// Whether a parameter is `inout`. The implementation then takes separate parameters, since a tuple can't
    /// hold an `inout`, and the mock writes the value back to the caller.
    var hasInoutParams: Bool {
        signature.parameters.contains(where: \.isInout)
    }

    /// Whether a parameter is `~Copyable`. The mock can't forward such a call to the superclass or a default
    /// implementation; see `Cuckoo.MockManager.crashOnNoncopyableArgumentForward`.
    var hasNoncopyableParams: Bool {
        signature.parameters.contains(where: \.isNoncopyable)
    }

    var hasGenericParams: Bool {
        !signature.genericParameters.isEmpty
    }

    /// The generic parameters a stubbing or verification proxy leaves out. The proxies take a pack as one
    /// `Cuckoo.ParameterPack` and a `~Copyable` argument as a `Cuckoo.NoncopyableArgument`, so a generic parameter that
    /// only such parameters use appears nowhere in a proxy's signature, and Swift couldn't infer it. A stubbing proxy
    /// keeps one the return type uses, inferred from the stubbed value; a verification proxy returns nothing that needs it.
    func genericsOmittedFromProxy(forVerification: Bool) -> [String] {
        let recordedAsPlaceholder = signature.parameters.filter { $0.isPack || $0.isNoncopyable }
        let otherParameters = signature.parameters.filter { !$0.isPack && !$0.isNoncopyable }
        return signature.genericParameters.map(\.name).filter { name in
            let isPlaceholderType = signature.genericParameters.contains { $0.name == name && $0.isPack }
                || recordedAsPlaceholder.contains { $0.type.description.mentions(name) }
            return isPlaceholderType
                && !otherParameters.contains { $0.type.description.mentions(name) }
                && (forVerification || !returnTypeMentions(name))
        }
    }

    /// Whether the return type names `typeName` anywhere, such as in a tuple's `repeat each T`.
    private func returnTypeMentions(_ typeName: String) -> Bool {
        returnType.map { $0.description.mentions(typeName) } ?? false
    }

    /// The method's generic parameters and `where` constraints as a proxy declares them; see
    /// `genericsOmittedFromProxy(forVerification:)`.
    func proxyGenerics(forVerification: Bool) -> (parameters: [GenericParameter], whereConstraints: [String]) {
        let omitted = genericsOmittedFromProxy(forVerification: forVerification)
        guard !omitted.isEmpty else { return (signature.genericParameters, signature.whereConstraints) }
        return (
            signature.genericParameters.filter { !omitted.contains($0.name) },
            signature.whereConstraints.filter { constraint in !omitted.contains { constraint.mentions($0) } }
        )
    }
    
    var hasNonPrimaryAssociatedTypeParams: Bool {
        guard let parent = parent?.asProtocol else { return false }
        return signature.containsTypes(named: parent.nonPrimaryAssociatedTypes.map(\.name))
    }

    func serialize() -> [String : Any] {
        guard let parent else {
            fatalError("Failed to find parent of method \(fullSignature). Please file a bug.")
        }
        
        let call = signature.parameters
            .map(\.call)
            .joined(separator: ", ")
        let forwardingCall = signature.parameters.map(\.forwardingCall).joined(separator: ", ")
        
        let staticGenericCall: String
        if let parent = parent.asProtocol, !parent.nonPrimaryAssociatedTypes.isEmpty {
            let nonPrimary = parent.nonPrimaryAssociatedTypes.map(\.name)
            
            let staticGenericCallableParameters = signature.parameters
                .map { $0.callAndCastTypes(named: nonPrimary, as: { Templates.staticGenericParameter + ".\($0)" }) }
                .joined(separator: ", ")
            
            staticGenericCall = if let returnType, returnType.containsTypes(named: nonPrimary) {
                "(\(staticGenericCallableParameters))".forceCast(as: returnType)
            } else {
                "(\(staticGenericCallableParameters))"
            }
        } else {
            staticGenericCall = "(\(call))"
        }
        
        let stubFunctionPrefix = parent.isClass ? "Class" : "Protocol"
        let returnString = returnType?.isVoid == false ? "" : "NoReturn"
        let throwingString = isThrowing ? "Throwing" : ""
        let stubFunction = "Cuckoo.\(stubFunctionPrefix)Stub\(returnString)\(throwingString)Function"

        let stubIsolation = parent.value.stubIsolation(forMember: stubbedIsolation)
        // Untyped even for typed throws: a typed-throws function type as a generic argument needs runtime
        // support that iOS 17 and macOS 14 lack. The mock narrows the error where it calls the closure.
        let throwsClause: String? = isThrowing ? "throws" : nil
        // A closure that is one of the `then` closure's own parameters must be `@escaping` to take it;
        // inside a tuple of several, closures already escape.
        func escapingIfClosure(_ type: ComplexType) -> String {
            let description = type.genericArgumentSafe.description
            return type.isClosure && !type.isOptional ? "@escaping \(description)" : description
        }
        let recordedParameters = signature.parameters.map(\.recordedValue).joined(separator: ", ")
        // The `then` closure reads the arguments from the manager's `arguments`, the recorded parameters, rather than
        // capturing them; see `MockManager.callInternal`.
        let parameterCount = signature.parameters.count
        // Each parameter's recorded value; an `inout` one is passed through a local variable the mock writes back.
        let separateArguments = signature.parameters.enumerated().map { index, parameter in
            if parameter.isInout {
                "&__inout\(index)"
            } else {
                parameterCount == 1 ? "arguments" : "arguments.\(index)"
            }
        }
        let implementationArguments = if stubIsolation.isolatedParameter != nil {
            // An actor mock's closure takes the mock, then each parameter.
            (["self"] + separateArguments).joined(separator: ", ")
        } else if hasInoutParams {
            // A closure with an `inout` parameter takes each parameter, since a tuple can't hold an `inout` one.
            separateArguments.joined(separator: ", ")
        } else {
            "arguments"
        }
        // The `then` closure can change an `inout` argument; the mock writes it back to the caller's variable.
        let inoutPrologue = signature.parameters.enumerated().filter { $0.element.isInout }.map { index, parameter in
            let value = parameterCount == 1 ? "arguments" : "arguments.\(index)"
            return "var __inout\(index) = \(value); defer { \(escapeReservedKeywords(for: parameter.usableName)) = __inout\(index) };"
        }.joined(separator: " ")

        /// The stub's input, output and `then` closure types. A class mock's body names `Self` as written; the proxies,
        /// where `Self` would be the proxy, name the mock, which is `final`, so both are the same type at runtime.
        /// A protocol's members already name `Self` through a typealias; see `Token.resolvingSelf()`.
        func stubTypes(resolvingSelfAs selfType: String?) -> (input: String, output: String, implementation: String) {
            func resolved(_ type: ComplexType) -> ComplexType {
                selfType.flatMap { selfType in type.replaceTypes(named: ["Self"], with: { _ in selfType }) } ?? type
            }
            let parameterTypes = signature.parameters.map { resolved($0.matchedType) }
            let input = parameterTypes.map(\.genericArgumentSafe.description).joined(separator: ", ")
            let output = returnType.map { resolved($0.withoutAttributes(except: ["@MainActor", "@Sendable"])).genericArgumentSafe.description } ?? "Void"
            // An `inout` parameter stays `inout` in the `then` closure, which can change the caller's variable.
            let separateParameterTypes = zip(signature.parameters, parameterTypes).map { parameter, type in
                "\(parameter.isInout ? "inout " : "")\(escapingIfClosure(type))"
            }
            let implementationInput = if let isolatedParameter = stubIsolation.isolatedParameter {
                // An actor mock's closure takes the mock, then each parameter.
                "(\(([isolatedParameter] + separateParameterTypes).joined(separator: ", ")))"
            } else if hasInoutParams {
                // A tuple can't hold an `inout` parameter, so the closure takes each parameter.
                "(\(separateParameterTypes.joined(separator: ", ")))"
            } else if parameterTypes.count == 1 {
                // Other closures take the parameters as one tuple, the way they're recorded.
                "((\(escapingIfClosure(parameterTypes[0]))))"
            } else {
                "((\(input)))"
            }
            let implementation = stubIsolation.implementationType(
                input: implementationInput,
                output: output,
                isAsync: isAsync,
                throwsClause: throwsClause
            )
            return (input, output, implementation)
        }
        let (genericInputTypes, genericReturnType, implementationType) = stubTypes(resolvingSelfAs: nil)
        let proxyTypes = stubTypes(resolvingSelfAs: parent.value.mockTypeName)

        let escapingParameterNames = signature.parameters.map { parameter in
            if !parameter.type.containsAttribute(named: "@escaping"), let closure = parameter.type.findClosure() {
                let parameterCount = closure.parameters.count
                let parameterSignature = parameterCount > 0 ? (1...parameterCount).map { _ in "_" }.joined(separator: ", ") : "()"

                // Swift 6 rejects a plain closure literal where a `@Sendable` one is expected.
                let sendable = parameter.type.containsAttribute(named: "@Sendable") ? "@Sendable " : ""

                // Typed, so the closure's `Never` result converts to a closure result too, such as `(Int) -> Int`.
                let type = parameter.type.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe
                return "({ \(sendable)\(parameterSignature) in fatalError(\"This is a stub! It's not supposed to be called!\") } as \(type))"
            } else {
                return parameter.recordedValue
            }
        }.joined(separator: ", ")

        return [
            "self": self,
            "documentation": documentation,
            "attributes": attributes,
            "isOverriding": parent.isClass,
            "name": name,
            "accessibility": accessibility.sourceName,
            "signature": signature.description,
            "parameters": signature.parameters,
            "parameterNames": signature.parameters.map { escapeReservedKeywords(for: $0.usableName) }.joined(separator: ", "),
            "sendingParameterNames": signature.parameters.filter(\.isSending).map { escapeReservedKeywords(for: $0.usableName) },
            "sendingParameterDeclarations": signature.parameters.filter(\.isSending).map { "_ \(escapeReservedKeywords(for: $0.usableName)): \($0.type)" },
            "recordedParameters": recordedParameters,
            "implementationArguments": implementationArguments,
            "inoutPrologue": inoutPrologue,
            "escapingParameterNames": escapingParameterNames,
            "returnType": returnType?.description ?? "",
            "returnsSending": returnType?.containsAttribute(named: "sending") ?? false,
            "genericReturnType": returnType == nil ? "" : genericReturnType,
            "isAsync": isAsync,
            // Under NonisolatedNonsendingByDefault, Swift 6.2 treats an async local function as `@concurrent`, so it
            // gets `nonisolated(nonsending)` there. Spelled out on 6.2 without the feature, it fails instead.
            // Drop the first variant when Swift 6.2 support ends.
            "localFunctionVariants": isAsync
                ? [
                    ["directive": "#if compiler(<6.3) && hasFeature(NonisolatedNonsendingByDefault)", "modifier": "nonisolated(nonsending) "],
                    ["directive": "#else", "modifier": ""],
                ]
                : [["directive": "", "modifier": ""]],
            "isThrowing": isThrowing,
            "throwsOnly": throwsOnly,
            "hasTypedThrows": signature.throwType?.isTyped ?? false,
            "throwType": signature.throwType?.keyword ?? "",
            "throwTypeError": signature.throwType?.type ?? "",
            "fullyQualifiedName": fullyQualifiedName,
            "call": call,
            "forwardingCall": forwardingCall,
            "superclassCall": "super.\(name)(\(forwardingCall))",
            "defaultCall": isStatic
                ? "Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\"\(fullyQualifiedName)\")"
                : "__defaultImplStub.value.\(name)\(isOptional ? "!" : "")(\(forwardingCall))",
            "isStatic": isStatic,
            "mentionsSelf": mentionsSelf,
            "staticKeyword": isStatic ? "static " : "",
            "manager": isStatic ? "cuckoo_staticManager" : "cuckoo_manager",
            "staticGenericCall": staticGenericCall,
            "parameterSignature": signature.parameters.map { $0.description }.joined(separator: ", "),
            "parameterSignatureWithoutNames": signature.parameters.map { "\($0.name): \($0.type)" }.joined(separator: ", "),
            "argumentSignature": signature.parameters.map { $0.type.description }.joined(separator: ", "),
            "stubFunction": stubFunction,
            "implementationType": implementationType,
            "sharingType": stubIsolation.sharingType,
            "isolationAttribute": isolation?.sourceDescription ?? "",
            "executionAttribute": executionAttribute ?? "",
            "inputTypes": signature.parameters.map { $0.type.withoutAttributes(except: ["@escaping", "@MainActor", "@Sendable"]).genericArgumentSafe.description }.joined(separator: ", "),
            "genericInputTypes": genericInputTypes,
            // The proxies' versions of the stub's types; see `stubTypes(resolvingSelfAs:)`.
            "stubInputTypes": proxyTypes.input,
            "stubReturnType": proxyTypes.output,
            "stubImplementationType": proxyTypes.implementation,
            // The verification proxy's return type names no generic parameter it leaves out; its result is never used.
            "verificationReturnType": genericsOmittedFromProxy(forVerification: true).contains(where: returnTypeMentions)
                ? "Any"
                : proxyTypes.output,
            "isOptional": isOptional,
            "hasClosureParams": hasClosureParams,
            "hasOptionalParams": hasOptionalParams,
            "hasGenericParams": hasGenericParams,
            "hasNoncopyableParams": hasNoncopyableParams,
            "genericParameters": signature.genericParameters.sourceDescription,
            "hasNonPrimaryAssociatedTypeParams": hasNonPrimaryAssociatedTypeParams,
            "hasCompilationCondition": hasCompilationCondition,
            "compilationConditionCheck": compilationConditionCheck,
        ]
    }
}

private extension String {
    /// Whether the source text names `identifier` as a whole word.
    func mentions(_ identifier: String) -> Bool {
        range(of: "\\b\(NSRegularExpression.escapedPattern(for: identifier))\\b", options: .regularExpression) != nil
    }
}
