import Foundation

/// Bold text for the generator's log and error messages, used only when the output can show it.
enum TerminalStyle {
    /// Whether messages get styled, decided once from the environment and whether standard output is a terminal.
    static let isEnabled = isEnabled(
        environment: ProcessInfo.processInfo.environment,
        outputIsTerminal: isatty(STDOUT_FILENO) != 0
    )

    /// Follows the `FORCE_COLOR` and `NO_COLOR` conventions: a set `FORCE_COLOR` always styles, a set `NO_COLOR`
    /// never does, and otherwise only a terminal that isn't `TERM=dumb` gets styled output. A variable set to an
    /// empty string or `0` counts as unset.
    static func isEnabled(environment: [String: String], outputIsTerminal: Bool) -> Bool {
        func isSet(_ name: String) -> Bool {
            guard let value = environment[name] else { return false }
            return !value.isEmpty && value != "0"
        }
        if isSet("FORCE_COLOR") {
            return true
        }
        if isSet("NO_COLOR") {
            return false
        }
        guard let terminal = environment["TERM"], terminal.lowercased() != "dumb" else {
            return false
        }
        return outputIsTerminal
    }

    static func bold(_ text: String, enabled: Bool = isEnabled) -> String {
        enabled ? "\u{1B}[1m\(text)\u{1B}[0m" : text
    }
}

extension String {
    /// The string in bold when the output can show it.
    var bold: String {
        TerminalStyle.bold(self)
    }
}
