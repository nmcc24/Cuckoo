import SwiftSyntax

/// Builds `__VerificationProxy_<Type>` and `__StaticVerificationProxy_<Type>`, the types `verify(_:)` returns, whose
/// members check the calls the mock recorded.
///
/// Like ``StubbingProxyBuilder``, each member is parsed as it's built, and `GeneratorHelper.format` lays the file out.
enum VerificationProxyBuilder {
    /// - Parameter isStatic: whether the proxy is for the mock type's static members (`verify(MockX.self)`), or its
    ///   instance members.
    static func build(_ container: any ContainerToken, isStatic: Bool) throws -> String {
        let name = "\(isStatic ? "__StaticVerificationProxy_" : "__VerificationProxy_")\(container.name)"
        let access = container.accessibility.spaced
        var members = MemberList()

        try members.append("private let cuckoo_manager: Cuckoo.MockManager", of: name)
        try members.append("private let callMatcher: Cuckoo.CallMatcher", of: name)
        try members.append("private let sourceLocation: Cuckoo.SourceLocation", of: name)
        members.separate()
        try members.append(lines([
            "\(access)init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {",
            "    self.cuckoo_manager = manager",
            "    self.callMatcher = callMatcher",
            "    self.sourceLocation = sourceLocation",
            "}",
        ]), of: name)
        // Every member is set off by a blank line, with or without a `#if`.
        for property in container.mockedProperties where property.isStatic == isStatic {
            members.separate()
            try members.append(members.conditional(property, source(of: property)), of: "\(container.name).\(property.name)")
        }
        for method in container.mockedMethods where method.isStatic == isStatic {
            members.separate()
            try members.append(members.conditional(method, source(of: method)), of: "\(container.name).\(method.name)")
        }
        let subscripts = container.mockedSubscripts.filter { $0.isStatic == isStatic }
        for (index, subscriptDeclaration) in subscripts.enumerated() {
            let declaration = "\(container.name)[]"
            let (accessor, type) = sources(of: subscriptDeclaration, number: index + 1)
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

    private static func source(of property: Variable) -> String {
        var source = property.repeatedAttributes.map(\.description)
        let type = GeneratorHelper.genericSafeType(from: (property.isReadOnly ? property.type : property.type.unoptionaled).description)
        source.append("var \(property.name): Cuckoo.\(property.verifyType)<\(type)> {")
        source.append("    return .init(manager: cuckoo_manager, name: \(Fragment.literal(property.name)), callMatcher: callMatcher, sourceLocation: sourceLocation)")
        source.append("}")
        return lines(source)
    }

    private static func source(of method: Method) -> String {
        let input = GeneratorHelper.genericSafeType(from: method.proxyStubTypes.input)
        let output = GeneratorHelper.genericSafeType(from: method.verificationReturnType)
        let generics = GeneratorHelper.matchableGenericTypes(from: method, forVerification: true)
        let parameters = GeneratorHelper.matchableParameterSignature(with: method.signature.parameters)
        let whereClause = GeneratorHelper.matchableGenericsWhereClause(from: method, forVerification: true)
        var source = method.repeatedAttributes.map(\.description)
        source.append("@discardableResult")
        source.append("func \(escapeReservedKeywords(for: method.name))\(generics)(\(parameters)) -> Cuckoo.__DoNotUse<(\(input)), \(output)>\(whereClause) {")
        source.append("    \(GeneratorHelper.parameterMatchers(for: method.signature.parameters))")
        source.append(contentsOf: verify(method))
        source.append("}")
        return lines(source)
    }

    /// The subscript, which takes the keys' matchers, and the type it returns, `__Subscript<number>`, whose `get()`
    /// and `set(_:)` verify the accessors' calls.
    private static func sources(of subscriptDeclaration: Subscript, number: Int) -> (accessor: String, type: String) {
        let getter = subscriptDeclaration.getter
        let getterTypes = getter.proxyStubTypes
        let getterInput = GeneratorHelper.genericSafeType(from: getterTypes.input)
        let keys = getter.signature.parameters
        let attributes = subscriptDeclaration.repeatedAttributes.map(\.description)

        let generics = GeneratorHelper.matchableGenericTypes(from: getter)
        let parameters = GeneratorHelper.matchableParameterSignature(with: keys)
        let whereClause = GeneratorHelper.matchableGenericsWhereClause(from: getter)
        var accessor = attributes
        accessor.append("subscript\(generics)(\(parameters)) -> __Subscript\(number)\(subscriptDeclaration.genericArgumentsClause)\(whereClause) {")
        accessor.append("    \(GeneratorHelper.parameterMatchers(for: keys))")
        accessor.append("    return .init(cuckoo_manager: cuckoo_manager, callMatcher: callMatcher, sourceLocation: sourceLocation, matchers: matchers)")
        accessor.append("}")

        var type = attributes
        type.append("nonisolated struct __Subscript\(number)\(subscriptDeclaration.genericParametersClause)\(subscriptDeclaration.whereClause) {")
        type.append("    fileprivate let cuckoo_manager: Cuckoo.MockManager")
        type.append("    fileprivate let callMatcher: Cuckoo.CallMatcher")
        type.append("    fileprivate let sourceLocation: Cuckoo.SourceLocation")
        type.append("    fileprivate let matchers: [Cuckoo.ParameterMatcher<(\(getterInput))>]")
        type.append("")
        type.append("    @discardableResult")
        type.append("    func get() -> Cuckoo.__DoNotUse<(\(getterInput)), \(GeneratorHelper.genericSafeType(from: getterTypes.output))> {")
        type.append(contentsOf: verify(getter).map { "    \($0)" })
        type.append("    }")
        if !subscriptDeclaration.isReadOnly {
            let setter = subscriptDeclaration.setter
            let setterInput = GeneratorHelper.genericSafeType(from: setter.proxyStubTypes.input)
            let index = subscriptDeclaration.newValueMatcherIndex
            type.append("")
            type.append("    @discardableResult")
            type.append("    func set<\(subscriptDeclaration.newValueMatcherGeneric(sendable: false))>(_ \(subscriptDeclaration.newValueName): M\(index)) -> Cuckoo.__DoNotUse<(\(setterInput)), Void> where \(subscriptDeclaration.newValueMatcherConstraint) {")
            type.append("        let matchers: [Cuckoo.ParameterMatcher<(\(setterInput))>] = \(subscriptDeclaration.keyMatchers(sendable: false))[\(subscriptDeclaration.newValueMatcher(sendable: false))]")
            type.append(contentsOf: verify(setter).map { "    \($0)" })
            type.append("    }")
        }
        type.append("}")
        return (lines(accessor), lines(type))
    }

    /// The lines that verify the member's calls against the matchers in `matchers`.
    private static func verify(_ method: Method) -> [String] {
        [
            "    return cuckoo_manager.verify(",
            "        \(Fragment.literal(method.fullyQualifiedName)),",
            "        callMatcher: callMatcher,",
            "        parameterMatchers: matchers,",
            "        sourceLocation: sourceLocation",
            "    )",
        ]
    }

    private static func lines(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
