protocol HasName: Token {
    var name: String { get }
}

extension HasName {
    var mockName: String {
        derivedName(MockNaming.current.prefix, MockNaming.current.suffix)
    }

    /// A name the mocks build from the type's, as `__StubbingProxy_Service` or `ServiceStub`. A backticked name,
    /// as `` `Type` ``, loses its backticks there, and keeps them only when the result isn't a plain identifier.
    func derivedName(_ prefix: String, _ suffix: String = "") -> String {
        guard name.hasPrefix("`"), name.hasSuffix("`"), name.count > 1 else { return prefix + name + suffix }
        let derived = prefix + String(name.dropFirst().dropLast()) + suffix
        let isPlainIdentifier = derived.first.map { $0 == "_" || $0.isLetter } == true
            && derived.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
        return isPlainIdentifier ? derived : "`\(derived)`"
    }

    var fullyQualifiedName: String {
        var names = [name]
        var parent: (any Token)? = parent?.value
        while let p = parent as? any HasName {
            names.insert(p.name, at: 0)
            parent = p.parent?.value
        }
        return names.joined(separator: ".")
    }

}
