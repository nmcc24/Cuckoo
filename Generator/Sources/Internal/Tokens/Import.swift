struct Import: Hashable, CustomStringConvertible {
    enum Target: Hashable {
        case library(name: String)
        case component(kind: String, name: String)
    }

    let target: Target
    /// The `#if` conditions the import is nested in, mirrored into the generated file.
    let compilationConditions: [String]
    /// Whether the source declares it `public import`, so its types may appear in public declarations.
    var isPublic = false
    /// The `@_spi` groups the source imports the module with.
    var spiGroups: [String] = []

    var description: String {
        switch target {
        case .library(let name):
            return name
        case .component(let kind, let name):
            return "\(kind) \(name)"
        }
    }
}
