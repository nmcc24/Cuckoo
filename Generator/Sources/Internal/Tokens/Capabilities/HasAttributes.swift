protocol HasAttributes: Token {
    var attributes: [Attribute] { get }
    /// The `#if` conditions the declaration is nested in, mirrored into the generated code.
    var compilationConditions: [String] { get }
}

extension HasAttributes {
    var compilationConditions: [String] { [] }

    var isUnavailableEverywhere: Bool {
        attributes.contains { $0.isUnavailableEverywhere }
    }

    /// `#if` conditions for the platforms the member is unavailable on.
    /// App extension platforms have no `#if` equivalent and don't affect a test target, so they're skipped.
    private var unavailablePlatformConditions: [String] {
        attributes.compactMap(\.unavailablePlatform).compactMap { platform in
            switch platform {
            case _ where platform.hasSuffix("ApplicationExtension"):
                nil
            case "macCatalyst":
                "targetEnvironment(macCatalyst)"
            case "OSX":
                "os(macOS)"
            default:
                "os(\(platform))"
            }
        }
    }

    /// Everything that decides whether the declaration exists when compiling:
    /// the `#if` blocks around it, and the platforms it's unavailable on.
    private var allCompilationConditions: [String] {
        compilationConditions + unavailablePlatformConditions.map { "!\($0)" }
    }

    var hasCompilationCondition: Bool {
        !allCompilationConditions.isEmpty
    }

    var compilationConditionCheck: String {
        hasCompilationCondition ? "#if \(allCompilationConditions.joined(separator: " && "))" : ""
    }

    func attributesSerialize() -> GeneratorContext {
        [
            "attributes": attributes,
        ]
    }
}
