import Foundation

// The plugin's reading of a Cuckoofile, line by line: a plugin can't depend on a TOML parser. The generator's tests
// link this file too (Generator/Tests/CuckoofileScan.swift), since a test target can't depend on a plugin.

/// A target as the unused-entry check sees it: its name, whether it depends on Cuckoo, as a target compiling mocks
/// does, and the modules it depends on directly.
struct ScannedTarget {
    var name: String
    var dependsOnCuckoo: Bool
    var dependencies: [String]
}

/// The names a Cuckoofile entry can generate for: every target's, and the direct dependencies of the targets that
/// depend on Cuckoo. A module those reach only through another one isn't among them, as the plugin generates only for
/// its target's direct dependencies.
func usableEntryNames(of targets: [ScannedTarget]) -> Set<String> {
    Set(targets.flatMap { [$0.name] + ($0.dependsOnCuckoo ? $0.dependencies : []) })
}

/// The warning for the Cuckoofile's entries that no target can use, as a misspelled `[modules.Netwrk]` is, or nil
/// when every entry names a target, or a module that a target depending on Cuckoo depends on directly: the plugin
/// generates only for its target's direct dependencies. Every plugin run sees every target, so each warns about the
/// same entries.
func unusedCuckoofileEntriesWarning(entries: Set<String>, usableNames: Set<String>) -> String? {
    let unused = entries.subtracting(usableNames).sorted()
    guard !unused.isEmpty else { return nil }
    let list = unused.map { "'\($0)'" }.joined(separator: ", ")
    return "The Cuckoofile's \(unused.count == 1 ? "entry" : "entries") \(list) \(unused.count == 1 ? "names" : "name") no target, and no module "
        + "that a target using Cuckoo depends on directly, so \(unused.count == 1 ? "it generates" : "they generate") nothing. "
        + "Rename \(unused.count == 1 ? "it" : "them") after one, or make the module a direct dependency of the test target: "
        + "one it reaches only through another module gets no mocks."
}

/// The names of the Cuckoofile's entries: `App` for `[modules.App]`, `[modules.App.options]`, a dotted
/// `modules.App.sources = …` key, or an `App = { … }` key in a `[modules]` table. Like
/// ``cuckoofileEntry(named:listsSourcesIn:)``, it reads the lines rather than the TOML.
func cuckoofileModuleNames(in configuration: String) -> Set<String> {
    var names: Set<String> = []
    for line in cuckoofileKeyLines(configuration) where line.key.count >= 2 && line.key[0] == "modules" {
        names.insert(line.key[1])
    }
    return names
}

/// Whether the Cuckoofile entry `name` lists its own `sources`, in a `[modules.name]` table, a
/// `[modules.name.sources]` table, a dotted `modules.name.sources` or `sources.Module` key or an inline table. It
/// reads the lines rather than the TOML, since a plugin can't depend on a parser; a wrong yes only costs a
/// generator run.
func cuckoofileEntry(named name: String, listsSourcesIn configuration: String) -> Bool {
    let sources = ["modules", name, "sources"]
    return cuckoofileKeyLines(configuration).contains { line in
        // An inline table, `App = { sources = [...] }`, counts if it mentions `sources` at all.
        line.key.starts(with: sources) || (line.key == ["modules", name] && line.value.contains("sources"))
    }
}

/// Whether a line inside a multi-line string closes it: three of its quotes in a row, which up to two more may come
/// before, as in `x""""`. In a basic string, `"""`, a backslash escapes the character after it, so `\"""` is an
/// escaped quote and two more, while `\\"""` is an escaped backslash and the delimiter.
func closesMultilineString(_ line: Substring, delimiter: Character) -> Bool {
    var index = line.startIndex
    while index < line.endIndex {
        let character = line[index]
        if delimiter == "\"", character == "\\" {
            index = line.index(index, offsetBy: 2, limitedBy: line.endIndex) ?? line.endIndex
            continue
        }
        guard character == delimiter else {
            index = line.index(after: index)
            continue
        }
        let run = line[index...].prefix { $0 == delimiter }
        if run.count >= 3 {
            return true
        }
        index = run.endIndex
    }
    return false
}

/// Each table header and key of a Cuckoofile, as the full key it defines (a key inside a table is prefixed with
/// the table's name), and the text after a key's `=`.
func cuckoofileKeyLines(_ configuration: String) -> [(key: [String], value: Substring)] {
    var lines: [(key: [String], value: Substring)] = []
    var table: [String] = []
    var multilineDelimiter: String?
    for line in configuration.split(whereSeparator: \.isNewline) {
        // Lines inside a multi-line string are its text, not keys.
        if let delimiter = multilineDelimiter {
            if closesMultilineString(line, delimiter: delimiter.first ?? "\"") {
                multilineDelimiter = nil
            }
            continue
        }
        // Only a delimiter in the line's TOML counts, not one in a comment.
        let code = withoutComment(line)
        for delimiter in [String(repeating: "\"", count: 3), "'''"] where code.ranges(of: delimiter).count == 1 {
            multilineDelimiter = delimiter
        }
        let line = line.drop { $0 == " " || $0 == "\t" }
        if line.first == "[" {
            table = tomlKeySegments(line.drop { $0 == "[" }, endingAt: "]")
            lines.append((table, ""))
        } else if line.first != "#", let (key, value) = tomlKeyAndValue(line) {
            lines.append((table + key, value))
        }
    }
    return lines
}

/// A line up to its `#` comment, if it has one outside quotes.
private func withoutComment(_ line: Substring) -> Substring {
    var quote: Character?
    var isEscaped = false
    for index in line.indices {
        let character = line[index]
        if let open = quote {
            // A basic string, in double quotes, escapes with a backslash; a literal one, in single quotes, doesn't.
            if isEscaped {
                isEscaped = false
            } else if open == "\"", character == "\\" {
                isEscaped = true
            } else if character == open {
                quote = nil
            }
        } else if character == "\"" || character == "'" {
            quote = character
        } else if character == "#" {
            return line[..<index]
        }
    }
    return line
}

/// The segments of a TOML key that runs until `terminator` outside quotes: `modules."My App".options` is
/// `["modules", "My App", "options"]`. Dots outside quotes separate segments, whitespace outside quotes is
/// dropped, and a quoted segment keeps its contents.
func tomlKeySegments(_ text: Substring, endingAt terminator: Character) -> [String] {
    var segments: [String] = []
    var current = ""
    var quote: Character?
    for character in text {
        if let open = quote {
            if character == open {
                quote = nil
            } else {
                current.append(character)
            }
            continue
        }
        switch character {
        case terminator:
            return segments + [current]
        case "\"", "'":
            quote = character
        case ".":
            segments.append(current)
            current = ""
        case " ", "\t":
            continue
        default:
            current.append(character)
        }
    }
    return segments + [current]
}

/// A `key = value` line's key segments and the text after its `=`, or nil when the line has no `=` outside quotes.
private func tomlKeyAndValue(_ line: Substring) -> (key: [String], value: Substring)? {
    var quote: Character?
    for index in line.indices {
        let character = line[index]
        if let open = quote {
            if character == open { quote = nil }
        } else if character == "\"" || character == "'" {
            quote = character
        } else if character == "=" {
            return (tomlKeySegments(line[..<index], endingAt: "="), line[line.index(after: index)...])
        }
    }
    return nil
}
