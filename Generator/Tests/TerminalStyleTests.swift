import Testing
@testable import CuckooGenerator

struct TerminalStyleTests {
    @Test(arguments: [
        ([:], true, false),
        (["TERM": "xterm-256color"], true, true),
        (["TERM": "xterm-256color"], false, false),
        (["TERM": "dumb"], true, false),
        (["TERM": "xterm", "NO_COLOR": "1"], true, false),
        (["TERM": "xterm", "NO_COLOR": ""], true, true),
        (["TERM": "xterm", "NO_COLOR": "0"], true, true),
        (["FORCE_COLOR": "1"], false, true),
        (["FORCE_COLOR": "1", "NO_COLOR": "1"], false, true),
        (["FORCE_COLOR": "0", "TERM": "xterm"], false, false),
    ] as [([String: String], Bool, Bool)])
    func stylingFollowsTheEnvironment(environment: [String: String], outputIsTerminal: Bool, expected: Bool) {
        #expect(TerminalStyle.isEnabled(environment: environment, outputIsTerminal: outputIsTerminal) == expected)
    }

    @Test
    func boldWrapsTheTextOnlyWhenEnabled() {
        #expect(TerminalStyle.bold("output", enabled: true) == "\u{1B}[1moutput\u{1B}[0m")
        #expect(TerminalStyle.bold("output", enabled: false) == "output")
    }
}
