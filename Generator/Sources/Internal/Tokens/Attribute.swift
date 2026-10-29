import Foundation

enum Attribute: Hashable, CustomStringConvertible {
    case available(arguments: [String])
    case objc
    case objcMembers
    /// `@_spi(group)`.
    case spi(group: String)

    var description: String {
        switch self {
        case .available(let arguments):
            "@available(\(arguments.joined(separator: ", ")))"
        case .objc:
            "@objc"
        case .objcMembers:
            "@objcMembers"
        case .spi(let group):
            "@_spi(\(group))"
        }
    }

    var spiGroup: String? {
        guard case .spi(let group) = self else { return nil }
        return group
    }

    /// `@available(*, unavailable)`: the member can't be overridden or called, so it isn't mocked.
    var isUnavailableEverywhere: Bool {
        guard case .available(let arguments) = self else { return false }
        return arguments.first == "*" && arguments.contains("unavailable")
    }

    /// The platform of `@available(<platform>, unavailable[, message: ...])`.
    var unavailablePlatform: String? {
        guard case .available(let arguments) = self,
              arguments.count >= 2,
              arguments[0] != "*",
              arguments[1] == "unavailable" else {
            return nil
        }

        return String(arguments[0])
    }
}
