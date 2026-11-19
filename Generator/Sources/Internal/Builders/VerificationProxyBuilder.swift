import SwiftSyntax

/// Builds `__VerificationProxy_<Type>` and `__StaticVerificationProxy_<Type>`, the types `verify(_:)` returns, whose
/// members check the calls the mock recorded.
///
/// Like ``StubbingProxyBuilder``, each member is parsed as it's built, and `GeneratorHelper.format` lays the file out.
enum VerificationProxyBuilder {
    /// - Parameter isStatic: whether the proxy is for the mock type's static members (`verify(MockX.self)`), or its
    ///   instance members.
    static func build(_ container: any ContainerToken, isStatic: Bool) throws -> String {
        let name = container.derivedName(isStatic ? "__StaticVerificationProxy_" : "__VerificationProxy_")
        let access = container.accessibility.spaced
        var members = MemberList()

        try members.append("private let cuckooManager: Cuckoo.MockManager", of: name)
        try members.append("private let cuckooCallMatcher: Cuckoo.CallMatcher", of: name)
        try members.append("private let cuckooSourceLocation: Cuckoo.CuckooSourceLocation", of: name)
        members.separate()
        try members.append(lines([
            "\(access)init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.CuckooSourceLocation) {",
            "    self.cuckooManager = manager",
            "    self.cuckooCallMatcher = callMatcher",
            "    self.cuckooSourceLocation = sourceLocation",
            "}",
        ]), of: name)
        // Every member is set off by a blank line, with or without a `#if`.
        for property in container.mockedProperties where property.isStatic == isStatic {
            members.separate()
            try members.append(members.conditional(property, source(of: property, access: GeneratorHelper.proxyAccess(of: property, in: container))), of: "\(container.name).\(property.name)")
        }
        let methods = container.mockedMethods.filter { $0.isStatic == isStatic }
        // An async method with a sync overload of the same signature would get the same verification member.
        // `verify(mock).load()` is the sync one, and the async one is a member of `verify(mock).async`, which a
        // synchronous block, `inOrder`'s for one, can name. Where a mocked member has taken that name, the async one's
        // member is `async` instead: `await verify(mock).load()`, as Swift picks a call's overload.
        let overloads = GeneratorHelper.asyncOverloads(among: methods)
        let hasNamespace = GeneratorHelper.canDeclareAsyncNamespace(in: container, isStatic: isStatic)
        var asyncOverloads: [Method] = []
        for (index, method) in methods.enumerated() {
            let access = GeneratorHelper.proxyAccess(of: method, in: container)
            let isOverload = overloads.contains(index)
            if isOverload, hasNamespace {
                asyncOverloads.append(method)
                continue
            }
            members.separate()
            try members.append(members.conditional(method, source(of: method, access: access, isAsync: isOverload)), of: "\(container.name).\(method.name)")
        }
        if !asyncOverloads.isEmpty {
            var overloads = MemberList()
            try overloads.append("fileprivate let cuckooManager: Cuckoo.MockManager", of: name)
            try overloads.append("fileprivate let cuckooCallMatcher: Cuckoo.CallMatcher", of: name)
            try overloads.append("fileprivate let cuckooSourceLocation: Cuckoo.CuckooSourceLocation", of: name)
            for method in asyncOverloads {
                overloads.separate()
                try overloads.append(overloads.conditional(method, source(of: method, access: GeneratorHelper.proxyAccess(of: method, in: container), isAsync: false)), of: "\(container.name).\(method.name)")
            }
            let namespace = "\(access)nonisolated struct \(GeneratorHelper.asyncNamespaceType) {\n}"
            guard var namespaceDeclaration = try Fragment.declaration(namespace, of: name).as(StructDeclSyntax.self) else {
                throw FragmentError.unparsable(declaration: name, source: namespace)
            }
            namespaceDeclaration.memberBlock.members = overloads.list
            members.separate()
            try members.append(lines([
                "/// The async overloads of the methods that have a sync one too, for a synchronous block.",
                "\(access)var async: \(GeneratorHelper.asyncNamespaceType) {",
                "    return .init(cuckooManager: cuckooManager, cuckooCallMatcher: cuckooCallMatcher, cuckooSourceLocation: cuckooSourceLocation)",
                "}",
            ]), of: name)
            members.separate()
            try members.append(namespaceDeclaration.description, of: name)
        }
        let subscripts = container.mockedSubscripts.filter { $0.isStatic == isStatic }
        for (index, subscriptDeclaration) in subscripts.enumerated() {
            let declaration = "\(container.name)[]"
            let (accessor, type) = sources(of: subscriptDeclaration, number: index + 1, access: GeneratorHelper.proxyAccess(of: subscriptDeclaration, in: container))
            members.separate()
            if subscriptDeclaration.hasCompilationCondition {
                try members.append(members.conditional(subscriptDeclaration, lines([accessor, "", type])), of: declaration)
            } else {
                try members.append(accessor, of: declaration)
                members.separate()
                try members.append(type, of: declaration)
            }
        }

        let header = "\(access)nonisolated struct \(name): Cuckoo.VerificationProxy {\n}"
        guard var structDeclaration = try Fragment.declaration(header, of: name).as(StructDeclSyntax.self) else {
            throw FragmentError.unparsable(declaration: name, source: header)
        }
        structDeclaration.memberBlock.members = members.list
        return structDeclaration.description
    }

    private static func source(of property: Variable, access memberAccess: Accessibility) -> String {
        var source = property.repeatedAttributes.map(\.description)
        source.append(contentsOf: isolation(property.stubIsolation))
        let type = GeneratorHelper.genericSafeType(from: (property.isReadOnly ? property.type : property.type.unoptionaled).description)
        source.append("\(memberAccess.spaced)var \(property.name): Cuckoo.\(property.verifyType)<\(type)> {")
        source.append("    return .init(manager: cuckooManager, name: \(Fragment.literal(property.name)), callMatcher: cuckooCallMatcher, sourceLocation: cuckooSourceLocation)")
        source.append("}")
        return lines(source)
    }

    private static func declaration(of method: Method, access memberAccess: Accessibility, isAsync: Bool) -> String {
        let input = GeneratorHelper.genericSafeType(from: method.proxyStubTypes.input)
        let output = GeneratorHelper.genericSafeType(from: method.verificationReturnType)
        let generics = GeneratorHelper.matchableGenericTypes(from: method, forVerification: true)
        let parameters = GeneratorHelper.matchableParameterSignature(with: method.signature.parameters, of: method)
        let whereClause = GeneratorHelper.matchableGenericsWhereClause(from: method, forVerification: true)
        // An async member that no global actor isolates runs on its caller's actor: a plain `async` one would send
        // the proxy, which isn't `Sendable`, off a caller on the main actor.
        let execution = isAsync && method.stubIsolation.globalActor == nil ? "nonisolated(nonsending) " : ""
        return "\(memberAccess.spaced)\(execution)func \(method.proxyName)\(generics)(\(parameters))\(isAsync ? " async" : "") -> Cuckoo.VerifiedCall<(\(input)), \(output)>\(whereClause) {"
    }

    private static func source(of method: Method, access memberAccess: Accessibility, isAsync: Bool) -> String {
        var source = method.repeatedAttributes.map(\.description)
        source.append(contentsOf: isolation(method.stubIsolation))
        source.append("@discardableResult")
        source.append(declaration(of: method, access: memberAccess, isAsync: isAsync))
        source.append("    \(GeneratorHelper.parameterMatchers(for: method.signature.parameters))")
        source.append(contentsOf: verify(method))
        source.append("}")
        return lines(source)
    }

    /// The subscript, which takes the keys' matchers, and the type it returns, `__Subscript<number>`, whose `get()`
    /// and `set(_:)` verify the accessors' calls.
    private static func sources(of subscriptDeclaration: Subscript, number: Int, access memberAccess: Accessibility) -> (accessor: String, type: String) {
        let getter = subscriptDeclaration.getter
        let getterTypes = getter.proxyStubTypes
        let getterInput = GeneratorHelper.genericSafeType(from: getterTypes.input)
        let keys = getter.signature.parameters
        let attributes = subscriptDeclaration.repeatedAttributes.map(\.description)

        let generics = GeneratorHelper.matchableGenericTypes(from: getter)
        let parameters = GeneratorHelper.matchableParameterSignature(with: keys, of: getter)
        let whereClause = GeneratorHelper.matchableGenericsWhereClause(from: getter)
        // The accessor only builds the keys' matchers; `get()` and `set(_:)` read the recorded arguments.
        let actor = isolation(getter.stubIsolation).map { "    \($0)" }
        var accessor = attributes
        accessor.append("\(memberAccess.spaced)subscript\(generics)(\(parameters)) -> __Subscript\(number)\(subscriptDeclaration.genericArgumentsClause)\(whereClause) {")
        accessor.append("    \(GeneratorHelper.parameterMatchers(for: keys))")
        accessor.append("    return .init(cuckooManager: cuckooManager, cuckooCallMatcher: cuckooCallMatcher, cuckooSourceLocation: cuckooSourceLocation, matchers: matchers)")
        accessor.append("}")

        var type = attributes
        type.append("\(memberAccess.spaced)nonisolated struct __Subscript\(number)\(subscriptDeclaration.genericParametersClause)\(subscriptDeclaration.whereClause) {")
        type.append("    fileprivate let cuckooManager: Cuckoo.MockManager")
        type.append("    fileprivate let cuckooCallMatcher: Cuckoo.CallMatcher")
        type.append("    fileprivate let cuckooSourceLocation: Cuckoo.CuckooSourceLocation")
        type.append("    fileprivate let matchers: [Cuckoo.ParameterMatcher<(\(getterInput))>]")
        type.append("")
        type.append(contentsOf: actor)
        type.append("    @discardableResult")
        type.append("    \(memberAccess.spaced)func get() -> Cuckoo.VerifiedCall<(\(getterInput)), \(GeneratorHelper.genericSafeType(from: getterTypes.output))> {")
        type.append(contentsOf: verify(getter).map { "    \($0)" })
        type.append("    }")
        if !subscriptDeclaration.isReadOnly {
            let setter = subscriptDeclaration.setter
            let setterInput = GeneratorHelper.genericSafeType(from: setter.proxyStubTypes.input)
            let index = subscriptDeclaration.newValueMatcherIndex
            type.append("")
            type.append(contentsOf: actor)
            type.append("    @discardableResult")
            type.append("    \(memberAccess.spaced)func set<\(subscriptDeclaration.newValueMatcherGeneric(sendable: false))>(_ \(subscriptDeclaration.newValueName): \(GeneratorHelper.matcherPrefix)\(index)) -> Cuckoo.VerifiedCall<(\(setterInput)), Void> where \(subscriptDeclaration.newValueMatcherConstraint) {")
            type.append("        let matchers: [Cuckoo.ParameterMatcher<(\(setterInput))>] = \(subscriptDeclaration.keyMatchers(sendable: false))[\(subscriptDeclaration.newValueMatcher(sendable: false))]")
            type.append(contentsOf: verify(setter).map { "    \($0)" })
            type.append("    }")
        }
        type.append("}")
        return (lines(accessor), lines(type))
    }

    /// The member's global actor, as an attribute, when it has one: its verifying member then runs only on that actor,
    /// where the arguments it reads were recorded, so a test can't read them while the mock still uses them.
    private static func isolation(_ stubIsolation: StubIsolation) -> [String] {
        stubIsolation.globalActor.map { ["@\($0)"] } ?? []
    }

    /// The lines that verify the member's calls against the matchers in `matchers`.
    private static func verify(_ method: Method) -> [String] {
        [
            "    return cuckooManager.verify(",
            "        \(Fragment.literal(method.fullyQualifiedName)),",
            "        callMatcher: cuckooCallMatcher,",
            "        parameterMatchers: matchers,",
            "        sourceLocation: cuckooSourceLocation",
            "    )",
        ]
    }

    private static func lines(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
