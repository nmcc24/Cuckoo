import Foundation

extension StubCall {
    /// The call as a test reads it: the member's name and its arguments.
    var readableDescription: String {
        if let bracketIndex = method.range(of: "(")?.lowerBound {
            return method[..<bracketIndex] + parametersAsString
        } else if method.hasSuffix("#set") {
            return method + parametersAsString
        } else {
            return method
        }
    }
}

/// A member's name and argument labels, read from the signature a mock records, such as
/// `count(characters p0: String) -> Int`, `subscript(_ p0: Int) -> String#set` or `name#get`.
struct MemberSignature {
    /// The member as Swift names it: `count(characters:)`, `subscript(_:)`, `name`.
    let name: String
    /// One per argument a matcher sees; a setter's new value comes last.
    private let labels: [String]

    init(_ method: String) {
        let isSetter = method.hasSuffix("#set")
        guard let open = method.firstIndex(of: "(") else {
            name = String(method.prefix { $0 != "#" })
            labels = isSetter ? ["newValue"] : []
            return
        }
        let parameters = Self.topLevelParameters(in: method[method.index(after: open)...])
        let declaredLabels = parameters.map { parameter in
            String(parameter.trimmingCharacters(in: .whitespaces).prefix { $0 != " " && $0 != ":" })
        }
        name = String(method[..<open]) + "(" + declaredLabels.map { $0 + ":" }.joined() + ")"
        labels = declaredLabels + (isSetter ? ["newValue"] : [])
    }

    /// How a failure names the argument at `index`.
    func argument(at index: Int) -> String {
        guard index < labels.count else {
            return "argument \(index + 1)"
        }
        switch labels[index] {
        case "_":
            return "argument \(index + 1)"
        case "newValue":
            return "the new value"
        case let label:
            return "`\(label):`"
        }
    }

    /// The comma-separated parameters up to the parenthesis that closes the list. Commas inside a parameter's type,
    /// as in `(Int, String) -> Void` or `[String: Int]`, don't split it.
    private static func topLevelParameters(in list: Substring) -> [Substring] {
        var parameters: [Substring] = []
        var depth = 0
        var start = list.startIndex
        var previous: Character?
        for index in list.indices {
            let character = list[index]
            defer { previous = character }
            switch character {
            case "(", "[", "<":
                depth += 1
            case ">" where previous == "-":
                continue
            case ")", "]", ">":
                if depth == 0 {
                    let last = list[start..<index]
                    if !last.trimmingCharacters(in: .whitespaces).isEmpty {
                        parameters.append(last)
                    }
                    return parameters
                }
                depth -= 1
            case "," where depth == 0:
                parameters.append(list[start..<index])
                start = list.index(after: index)
            default:
                break
            }
        }
        return parameters
    }
}

/// Numbers `lines` from 1, one per line, indented under a heading.
func numberedList(_ lines: [String]) -> String {
    lines.enumerated().map { "  \($0 + 1). \($1)" }.joined(separator: "\n")
}
