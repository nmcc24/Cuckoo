import SwiftSyntax

/// Builds `__StubbingProxy_<Type>` and `__StaticStubbingProxy_<Type>`, the types `stub(_:block:)` hands its block,
/// whose members return the stubs of the mock's members.
///
/// Like ``NopImplStubBuilder``, each member is parsed as it's built, and `GeneratorHelper.format` lays the file out.
enum StubbingProxyBuilder {
    /// - Parameter isStatic: whether the proxy is for the mock type's static members (`stub(MockX.self)`), or its
    ///   instance members.
    static func build(_ container: any ContainerToken, isStatic: Bool) throws -> String {
        let name = "\(isStatic ? "__StaticStubbingProxy_" : "__StubbingProxy_")\(container.name)"
        let mockName = container.mockName
        let access = container.accessibility.spaced
        var members = MemberList()

        try members.append("private let cuckoo_manager: Cuckoo.MockManager", of: name)
        members.separate()
        try members.append(lines([
            "\(access)init(manager: Cuckoo.MockManager) {",
            "    self.cuckoo_manager = manager",
            "}",
        ]), of: name)
        for property in container.mockedProperties where property.isStatic == isStatic {
            try members.append(property, source: source(of: property, mockName: mockName), of: "\(container.name).\(property.name)")
        }
        for method in container.mockedMethods where method.isStatic == isStatic {
            try members.append(method, source: source(of: method, mockName: mockName), of: "\(container.name).\(method.name)")
        }
        let subscripts = container.mockedSubscripts.filter { $0.isStatic == isStatic }
        for (index, subscriptDeclaration) in subscripts.enumerated() {
            let declaration = "\(container.name)[]"
            let (accessor, type) = sources(of: subscriptDeclaration, number: index + 1, mockName: mockName)
            if subscriptDeclaration.hasCompilationCondition {
                try members.append(subscriptDeclaration, source: lines([accessor, "", type]), of: declaration)
            } else {
                try members.append(subscriptDeclaration, source: accessor, of: declaration)
                members.separate()
                try members.append(type, of: declaration)
            }
        }

        let header = "\(access)nonisolated struct \(name): Cuckoo.StubbingProxy {\n}"
        guard var structDeclaration = try Fragment.declaration(header, of: name).as(StructDeclSyntax.self) else {
            throw FragmentError.unparsable(declaration: name, source: header)
        }
        structDeclaration.memberBlock.members = members.list
        return structDeclaration.description
    }

    private static func source(of property: Variable, mockName: String) -> String {
        var source = property.repeatedAttributes.map(\.description)
        let arguments = GeneratorHelper.genericSafeType(from: property.stubGenericArguments)
        source.append("var \(property.name): Cuckoo.\(property.stubType)<\(mockName), \(arguments)> {")
        source.append("    return .init(manager: cuckoo_manager, name: \(Fragment.literal(property.name)))")
        source.append("}")
        return lines(source)
    }

    private static func source(of method: Method, mockName: String) -> String {
        let types = method.proxyStubTypes
        var arguments = ["(\(GeneratorHelper.genericSafeType(from: types.input)))"]
        if (method.returnType?.description ?? "") != "Void" {
            arguments.append(GeneratorHelper.genericSafeType(from: types.output))
        }
        if method.isThrowing {
            arguments.append(method.signature.throwType?.type ?? "")
        }
        arguments.append(GeneratorHelper.genericSafeType(from: types.implementation))
        arguments.append(method.stubIsolation.sharingType)

        let sendable = method.stubIsolation.sharing == .shared
        let generics = GeneratorHelper.matchableGenericTypes(from: method, sendable: sendable)
        let parameters = GeneratorHelper.matchableParameterSignature(with: method.signature.parameters)
        let whereClause = GeneratorHelper.matchableGenericsWhereClause(from: method)
        var source = method.repeatedAttributes.map(\.description)
        source.append("func \(escapeReservedKeywords(for: method.name))\(generics)(\(parameters)) -> \(method.stubFunction)<\(arguments.joined(separator: ", "))>\(whereClause) {")
        source.append("    \(GeneratorHelper.parameterMatchers(for: method.signature.parameters, sendable: sendable))")
        source.append(contentsOf: createStub(for: method, mockName: mockName))
        source.append("}")
        return lines(source)
    }

    /// The subscript, which takes the keys' matchers, and the type it returns, `__Subscript<number>`, whose `get`
    /// and `set(_:)` return the accessors' stubs.
    private static func sources(of subscriptDeclaration: Subscript, number: Int, mockName: String) -> (accessor: String, type: String) {
        let getter = subscriptDeclaration.getter
        let getterTypes = getter.proxyStubTypes
        let getterInput = GeneratorHelper.genericSafeType(from: getterTypes.input)
        let keys = getter.signature.parameters
        let attributes = subscriptDeclaration.repeatedAttributes.map(\.description)

        let sendable = getter.stubIsolation.sharing == .shared
        let generics = GeneratorHelper.matchableGenericTypes(from: getter, sendable: sendable)
        let parameters = GeneratorHelper.matchableParameterSignature(with: keys)
        let whereClause = GeneratorHelper.matchableGenericsWhereClause(from: getter)
        var accessor = attributes
        accessor.append("subscript\(generics)(\(parameters)) -> __Subscript\(number)\(subscriptDeclaration.genericArgumentsClause)\(whereClause) {")
        accessor.append("    \(GeneratorHelper.parameterMatchers(for: keys, sendable: sendable))")
        accessor.append("    return .init(cuckoo_manager: cuckoo_manager, matchers: matchers)")
        accessor.append("}")

        var getterArguments = ["(\(getterInput))", GeneratorHelper.genericSafeType(from: getterTypes.output)]
        if getter.isThrowing {
            getterArguments.append(getter.signature.throwType?.type ?? "")
        }
        getterArguments.append(GeneratorHelper.genericSafeType(from: getterTypes.implementation))
        getterArguments.append(getter.stubIsolation.sharingType)

        var type = attributes
        type.append("nonisolated struct __Subscript\(number)\(subscriptDeclaration.genericParametersClause)\(subscriptDeclaration.whereClause) {")
        type.append("    fileprivate let cuckoo_manager: Cuckoo.MockManager")
        type.append("    fileprivate let matchers: [\(GeneratorHelper.matcherType(sendable: sendable))<(\(getterInput))>]")
        type.append("")
        type.append("    var get: \(getter.stubFunction)<\(getterArguments.joined(separator: ", "))> {")
        type.append(contentsOf: createStub(for: getter, mockName: mockName).map { "    \($0)" })
        type.append("    }")
        if !subscriptDeclaration.isReadOnly {
            let setter = subscriptDeclaration.setter
            let setterTypes = setter.proxyStubTypes
            let setterInput = GeneratorHelper.genericSafeType(from: setterTypes.input)
            let setterArguments = [
                "(\(setterInput))",
                GeneratorHelper.genericSafeType(from: setterTypes.implementation),
                setter.stubIsolation.sharingType,
            ]
            let index = subscriptDeclaration.newValueMatcherIndex
            type.append("")
            type.append("    func set<\(subscriptDeclaration.newValueMatcherGeneric(sendable: sendable))>(_ \(subscriptDeclaration.newValueName): M\(index)) -> \(setter.stubFunction)<\(setterArguments.joined(separator: ", "))> where \(subscriptDeclaration.newValueMatcherConstraint) {")
            type.append("        let matchers: [\(GeneratorHelper.matcherType(sendable: sendable))<(\(setterInput))>] = \(subscriptDeclaration.keyMatchers(sendable: sendable))[\(subscriptDeclaration.newValueMatcher(sendable: sendable))]")
            type.append(contentsOf: createStub(for: setter, mockName: mockName).map { "    \($0)" })
            type.append("    }")
        }
        type.append("}")
        return (lines(accessor), lines(type))
    }

    /// The lines that return the member's stub, made from the matchers in `matchers`.
    private static func createStub(for method: Method, mockName: String) -> [String] {
        [
            "    return .init(stub: cuckoo_manager.createStub(for: \(mockName).self,",
            "        method: \(Fragment.literal(method.fullyQualifiedName)),",
            "        parameterMatchers: matchers",
            "    ))",
        ]
    }

    private static func lines(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
