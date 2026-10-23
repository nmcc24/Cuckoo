import Foundation

enum Attribute: Hashable, CustomStringConvertible {
    case available(arguments: [String])
    case objc
    case objcMembers

    var description: String {
        switch self {
        case .available(let arguments):
            "@available(\(arguments.joined(separator: ", ")))"
        case .objc:
            "@objc"
        case .objcMembers:
            "@objcMembers"
        }
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
