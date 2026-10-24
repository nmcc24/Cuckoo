struct Import: Hashable, CustomStringConvertible {
    enum Target: Hashable {
        case library(name: String)
        case component(kind: String, name: String)
    }

    let target: Target
    /// The `#if` conditions the import is nested in, mirrored into the generated file.
    let compilationConditions: [String]

    var description: String {
        switch target {
        case .library(let name):
            return name
        case .component(let kind, let name):
            return "\(kind) \(name)"
        }
    }
}
