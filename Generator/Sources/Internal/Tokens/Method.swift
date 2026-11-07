import Foundation
import RegexBuilder

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
    /// What a subscript's accessor forwards to instead of a method call: `super[...]` and the default implementation's.
    var superclassCallOverride: String?
    var defaultCallOverride: String?

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

    /// Whether the `then` closure takes the parameter's own argument, borrowed. A `~Copyable` argument is recorded as
    /// a placeholder, but the mock passes the argument itself to the closure, which the manager calls before the
    /// member returns. A generic one stays the placeholder: the proxies leave its type out, so Swift couldn't infer it.
    func passesBorrowed(_ parameter: MethodParameter) -> Bool {
        parameter.isNoncopyable && !parameter.isInout
            && !signature.genericParameters.contains { parameter.type.description.mentions($0.name) }
    }

    /// Whether the `then` closure takes each parameter on its own: a tuple can't hold an `inout` or `~Copyable` one.
    private var passesSeparateArguments: Bool {
        hasInoutParams || signature.parameters.contains(where: passesBorrowed)
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
    
    /// Whether the member runs on a global actor, its own or its protocol's.
    private var isGlobalActorIsolated: Bool {
        if case .globalActor? = isolation ?? parent?.asProtocol?.isolation { true } else { false }
    }

    /// The type a stub asks `DefaultValueRegistry` for, as the stub's generic arguments name it; empty for no return type.
    var defaultValueType: String {
        returnType.map { $0.withoutAttributes(except: ["@MainActor", "@Sendable"]).genericArgumentSafe.description } ?? ""
    }

    /// A generic method can't be stored as a closure, so the default implementation calls it on the existential, which
    /// erases the non-primary associated types. Where its parameters or its return type use one, the call goes through
    /// the opened existential instead, casting between the two types the generic initializer requires to be equal.
    var usesNonPrimaryAssociatedTypes: Bool {
        guard let parent = parent?.asProtocol else { return false }
        let names = parent.nonPrimaryAssociatedTypes.map(\.name)
        return signature.containsTypes(named: names) || returnType?.containsTypes(named: names) == true
    }

    /// The stub function type the stubbing proxy returns, such as `Cuckoo.ProtocolStubThrowingFunction`.
    var stubFunction: String {
        let prefix = parent?.isClass == true ? "Class" : "Protocol"
        let returnString = returnType?.isVoid == false ? "" : "NoReturn"
        let throwingString = isThrowing ? "Throwing" : ""
        return "Cuckoo.\(prefix)Stub\(returnString)\(throwingString)Function"
    }

    /// The isolation and sharing of the stub's `then` closures.
    var stubIsolation: StubIsolation {
        guard let parent else {
            fatalError("Failed to find parent of method \(fullSignature). Please file a bug.")
        }
        return parent.value.stubIsolation(forMember: stubbedIsolation)
    }

    /// The stub's types as the proxies name them; see `stubTypes(resolvingSelfAs:)`.
    var proxyStubTypes: (input: String, output: String, implementation: String) {
        stubTypes(resolvingSelfAs: parent?.value.mockTypeName)
    }

    /// The verification proxy's return type, which names no generic parameter it leaves out; its result is never used.
    var verificationReturnType: String {
        genericsOmittedFromProxy(forVerification: true).contains(where: returnTypeMentions) ? "Any" : proxyStubTypes.output
    }

    /// The stub's input, output and `then` closure types. A class mock's body names `Self` as written; the proxies,
    /// where `Self` would be the proxy, name the mock, which is `final`, so both are the same type at runtime.
    /// A protocol's members already name `Self` through a typealias; see `Token.resolvingSelf()`.
    func stubTypes(resolvingSelfAs selfType: String?) -> (input: String, output: String, implementation: String) {
        func resolved(_ type: ComplexType) -> ComplexType {
            selfType.flatMap { selfType in type.replaceTypes(named: ["Self"], with: { _ in selfType }) } ?? type
        }
        // A closure that is one of the `then` closure's own parameters must be `@escaping` to take it;
        // inside a tuple of several, closures already escape.
        func escapingIfClosure(_ type: ComplexType) -> String {
            let description = type.genericArgumentSafe.description
            return type.isClosure && !type.isOptional ? "@escaping \(description)" : description
        }
        let stubIsolation = self.stubIsolation
        let parameterTypes = signature.parameters.map { resolved($0.matchedType) }
        let input = parameterTypes.map(\.genericArgumentSafe.description).joined(separator: ", ")
        let output = returnType.map { resolved($0.withoutAttributes(except: ["@MainActor", "@Sendable"])).genericArgumentSafe.description } ?? "Void"
        // An `inout` parameter stays `inout` in the `then` closure, which can change the caller's variable.
        // A `~Copyable` one is borrowed for the closure's call.
        let separateParameterTypes = zip(signature.parameters, parameterTypes).map { parameter, type in
            if passesBorrowed(parameter) {
                "borrowing \(resolved(parameter.type.withoutAttributes()).genericArgumentSafe.description)"
            } else {
                "\(parameter.isInout ? "inout " : "")\(escapingIfClosure(type))"
            }
        }
        let implementationInput = if let isolatedParameter = stubIsolation.isolatedParameter {
            // An actor mock's closure takes the mock, then each parameter.
            "(\(([isolatedParameter] + separateParameterTypes).joined(separator: ", ")))"
        } else if passesSeparateArguments {
            "(\(separateParameterTypes.joined(separator: ", ")))"
        } else if parameterTypes.count == 1 {
            // Other closures take the parameters as one tuple, the way they're recorded.
            "((\(escapingIfClosure(parameterTypes[0]))))"
        } else {
            "((\(input)))"
        }
        // Untyped even for typed throws: a typed-throws function type as a generic argument needs runtime
        // support that iOS 17 and macOS 14 lack. The mock narrows the error where it calls the closure.
        let implementation = stubIsolation.implementationType(
            input: implementationInput,
            output: output,
            isAsync: isAsync,
            throwsClause: isThrowing ? "throws" : nil
        )
        return (input, output, implementation)
    }

    /// The arguments that call the method with its own parameters, `label: p0`.
    var call: String {
        signature.parameters.map(\.call).joined(separator: ", ")
    }

    /// The parameters' names, as the method's body refers to them.
    var parameterNames: String {
        signature.parameters.map { escapeReservedKeywords(for: $0.usableName) }.joined(separator: ", ")
    }

    var sendingParameterNames: [String] {
        signature.parameters.filter(\.isSending).map { escapeReservedKeywords(for: $0.usableName) }
    }

    /// The `sending` parameters as a local function declares them, `_ p0: T`.
    var sendingParameterDeclarations: [String] {
        signature.parameters.filter(\.isSending).map { "_ \(escapeReservedKeywords(for: $0.usableName)): \($0.type)" }
    }

    /// The parameters' types as a closure's parameter list names them.
    var inputTypes: String {
        signature.parameters.map { $0.type.withoutAttributes(except: ["@escaping", "@MainActor", "@Sendable"]).genericArgumentSafe.description }.joined(separator: ", ")
    }

    /// The parenthesized arguments that call the method on a value of the static generic type; the arguments and the
    /// result are cast where they use the protocol's non-primary associated types.
    var staticGenericCall: String {
        guard let parent = parent?.asProtocol, !parent.nonPrimaryAssociatedTypes.isEmpty else {
            return "(\(call))"
        }
        let nonPrimary = parent.nonPrimaryAssociatedTypes.map(\.name)
        let staticGenericCallableParameters = signature.parameters
            .map { $0.callAndCastTypes(named: nonPrimary, as: { GeneratedNames.staticGenericParameter + ".\($0)" }) }
            .joined(separator: ", ")
        if let returnType, returnType.containsTypes(named: nonPrimary) {
            return "(\(staticGenericCallableParameters))".forceCast(as: returnType)
        }
        return "(\(staticGenericCallableParameters))"
    }

    /// The `#if` directive and modifier of each copy of a local function the mock declares.
    ///
    /// Under NonisolatedNonsendingByDefault, Swift 6.2 treats an async local function as `@concurrent`, so it
    /// gets `nonisolated(nonsending)` there. Spelled out on 6.2 without the feature, it fails instead.
    /// A global actor's member needs neither: its local function is isolated to the actor, and
    /// `nonisolated(nonsending)` would run the actor-isolated call from a nonisolated context.
    /// Drop the first variant when Swift 6.2 support ends.
    var localFunctionVariants: [(directive: String, modifier: String)] {
        guard isAsync && !isGlobalActorIsolated else { return [("", "")] }
        return [
            ("#if compiler(<6.3) && hasFeature(NonisolatedNonsendingByDefault)", "nonisolated(nonsending) "),
            ("#else", ""),
        ]
    }

    /// The parameters as the mock manager records them.
    var recordedParameters: String {
        signature.parameters.map(\.recordedValue).joined(separator: ", ")
    }

    /// The arguments the mock passes to the `then` closure. The closure reads them from the manager's `arguments`,
    /// the recorded parameters, rather than capturing them; see `MockManager.callInternal`.
    var implementationArguments: String {
        let parameterCount = signature.parameters.count
        // Each parameter's recorded value; an `inout` one is passed through a local variable the mock writes back.
        let separateArguments = signature.parameters.enumerated().map { index, parameter in
            if parameter.isInout {
                "&__inout\(index)"
            } else if passesBorrowed(parameter) {
                escapeReservedKeywords(for: parameter.usableName)
            } else {
                parameterCount == 1 ? "arguments" : "arguments.\(index)"
            }
        }
        if stubIsolation.isolatedParameter != nil {
            // An actor mock's closure takes the mock, then each parameter.
            return (["self"] + separateArguments).joined(separator: ", ")
        } else if passesSeparateArguments {
            return separateArguments.joined(separator: ", ")
        } else {
            return "arguments"
        }
    }

    /// The `then` closure can change an `inout` argument; the mock writes it back to the caller's variable.
    var inoutPrologue: String {
        let parameterCount = signature.parameters.count
        return signature.parameters.enumerated().filter { $0.element.isInout }.map { index, parameter in
            let value = parameterCount == 1 ? "arguments" : "arguments.\(index)"
            return "var __inout\(index) = \(value); defer { \(escapeReservedKeywords(for: parameter.usableName)) = __inout\(index) };"
        }.joined(separator: " ")
    }

    /// The parameters as the mock manager records them for verification: a non-escaping closure is replaced by a stub
    /// that crashes if called.
    var escapingParameterNames: String {
        signature.parameters.map { parameter in
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
    }

    var returnsSending: Bool {
        returnType?.containsAttribute(named: "sending") ?? false
    }

    /// The call that forwards to the superclass's implementation.
    var superclassCall: String {
        superclassCallOverride ?? "super.\(name)(\(signature.parameters.map(\.forwardingCall).joined(separator: ", ")))"
    }

    /// The call that forwards to the default implementation.
    var defaultCall: String {
        if isStatic {
            return "Cuckoo.MockManager.crashOnStaticDefaultImplementationCall(\"\(fullyQualifiedName)\")"
        }
        return defaultCallOverride ?? "__defaultImplStub.value.\(name)\(isOptional ? "!" : "")(\(signature.parameters.map(\.forwardingCall).joined(separator: ", ")))"
    }

}

private extension String {
    /// Whether the source text names `identifier` as a whole word.
    func mentions(_ identifier: String) -> Bool {
        contains(Regex {
            Anchor.wordBoundary
            identifier
            Anchor.wordBoundary
        }.wordBoundaryKind(.simple))
    }
}
