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
        return name == other.name && signature.isApiEqual(to: other.signature)
    }
}

extension Method {
    var fullyQualifiedName: String {
        "\(name)\(signature.description.trimmed)"
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
    
    var hasGenericParams: Bool {
        !signature.genericParameters.isEmpty
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

        let stubIsolation = parent.value.stubIsolation(forMember: isolation)
        let genericParameterTypes = signature.parameters.map { $0.type.withoutAttributes(except: ["@MainActor", "@Sendable"]) }
        let genericInputTypes = genericParameterTypes.map(\.genericArgumentSafe.description).joined(separator: ", ")
        let genericReturnType = returnType?.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe.description ?? "Void"
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
        let implementationInput: String
        let implementationArguments: String
        if let isolatedParameter = stubIsolation.isolatedParameter {
            // An actor mock's closure takes the mock, then each parameter.
            implementationInput = "(\(([isolatedParameter] + genericParameterTypes.map(escapingIfClosure)).joined(separator: ", ")))"
            implementationArguments = (["self"] + signature.parameters.map(\.recordedValue)).joined(separator: ", ")
        } else {
            // Other closures take the parameters as one tuple, the way they're recorded.
            implementationInput = if genericParameterTypes.count == 1 {
                "((\(escapingIfClosure(genericParameterTypes[0]))))"
            } else {
                "((\(genericInputTypes)))"
            }
            implementationArguments = "(\(recordedParameters))"
        }
        let implementationType = stubIsolation.implementationType(
            input: implementationInput,
            output: genericReturnType,
            isAsync: isAsync,
            throwsClause: throwsClause
        )

        let escapingParameterNames = signature.parameters.map { parameter in
            if !parameter.type.containsAttribute(named: "@escaping"), let closure = parameter.type.findClosure() {
                let parameterCount = closure.parameters.count
                let parameterSignature = parameterCount > 0 ? (1...parameterCount).map { _ in "_" }.joined(separator: ", ") : "()"

                // Swift 6 rejects a plain closure literal where a `@Sendable` one is expected.
                let sendable = parameter.type.containsAttribute(named: "@Sendable") ? "@Sendable " : ""

                return "{ \(sendable)\(parameterSignature) in fatalError(\"This is a stub! It's not supposed to be called!\") }"
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
            "escapingParameterNames": escapingParameterNames,
            "returnType": returnType?.description ?? "",
            "returnsSending": returnType?.containsAttribute(named: "sending") ?? false,
            "genericReturnType": returnType?.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe.description ?? "",
            "isAsync": isAsync,
            "isThrowing": isThrowing,
            "throwsOnly": throwsOnly,
            "hasTypedThrows": signature.throwType?.isTyped ?? false,
            "throwType": signature.throwType?.keyword ?? "",
            "throwTypeError": signature.throwType?.type ?? "",
            "fullyQualifiedName": fullyQualifiedName,
            "call": call,
            "forwardingCall": signature.parameters.map(\.forwardingCall).joined(separator: ", "),
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
            "genericInputTypes": signature.parameters.map { $0.type.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe.description }.joined(separator: ", "),
            "isOptional": isOptional,
            "hasClosureParams": hasClosureParams,
            "hasOptionalParams": hasOptionalParams,
            "hasGenericParams": hasGenericParams,
            "genericParameters": signature.genericParameters.sourceDescription,
            "hasNonPrimaryAssociatedTypeParams": hasNonPrimaryAssociatedTypeParams,
            "hasCompilationCondition": hasCompilationCondition,
            "compilationConditionCheck": compilationConditionCheck,
        ]
    }
}
