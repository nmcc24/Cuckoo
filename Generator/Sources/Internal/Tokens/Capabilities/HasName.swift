protocol HasName: Token {
    var name: String { get }
}

extension HasName {
    var mockName: String {
        MockNaming.current.mockName(of: name)
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

    func nameSerialize() -> GeneratorContext {
        [
            "name": name,
            "mockName": mockName,
        ]
    }
}
