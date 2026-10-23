protocol HasAttributes: Token {
    var attributes: [Attribute] { get }
}

extension HasAttributes {
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

    var hasUnavailablePlatforms: Bool {
        !unavailablePlatformConditions.isEmpty
    }

    var unavailablePlatformsCheck: String {
        hasUnavailablePlatforms ? "#if \(unavailablePlatformConditions.map { "!\($0)" }.joined(separator: " && "))" : ""
    }

    func attributesSerialize() -> GeneratorContext {
        [
            "attributes": attributes,
        ]
    }
}
