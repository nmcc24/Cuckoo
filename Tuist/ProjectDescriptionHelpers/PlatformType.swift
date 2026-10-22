import ProjectDescription

public enum PlatformType: String {
    case iOS
    case macOS
    case tvOS
    case watchOS

    public var destinations: Destinations {
        switch self {
        case .iOS:
            return [.iPhone, .iPad]
        case .macOS:
            return [.mac]
        case .tvOS:
            return [.appleTv]
        case .watchOS:
            return [.appleWatch]
        }
    }

    public var deploymentTargets: DeploymentTargets {
        switch self {
        case .iOS:
            return .iOS("17.0")
        case .macOS:
            return .macOS("14.0")
        case .tvOS:
            return .tvOS("17.0")
        case .watchOS:
            return .watchOS("10.0")
        }
    }
}
