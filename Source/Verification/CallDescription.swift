extension StubCall {
    /// The call as a test reads it: the member's name and its arguments, such as `count("b")`, `name`, `name = 1`,
    /// `[0]` or `[0] = "a"`.
    var readableDescription: String {
        let arguments = (self as? any DescribedArguments)?.argumentDescriptions
        if let (baseName, _) = MemberSignature.baseNameAndParameterList(in: method) {
            guard baseName == "subscript" || baseName.hasSuffix(" subscript"), let arguments else {
                return baseName + parametersAsString
            }
            let prefix = baseName.dropLast("subscript".count)
            if method.hasSuffix("#set"), let newValue = arguments.last {
                return prefix + "[" + arguments.dropLast().joined(separator: ", ") + "] = " + newValue
            }
            return prefix + "[" + arguments.joined(separator: ", ") + "]"
        }
        let name = MemberSignature(method).name
        if method.hasSuffix("#set") {
            let newValue = (self as? any DescribedArguments)?.valueDescription ?? String(parametersAsString.dropFirst().dropLast())
            return name + " = " + newValue
        }
        return name
    }

    /// The call as a failure's sentence names it: `count(characters:) with ("b")`, `noReturn()`, `the getter of
    /// name` or `the setter of name with (1)`.
    var memberAndArguments: String {
        let name = MemberSignature(method).name
        let arguments = parametersAsString == "()" ? "" : " with \(parametersAsString)"
        if MemberSignature.baseNameAndParameterList(in: method) == nil || name.hasPrefix("subscript(") {
            if method.hasSuffix("#get") {
                return "the getter of \(name)" + arguments
            }
            if method.hasSuffix("#set") {
                return "the setter of \(name)" + arguments
            }
        }
        return name + arguments
    }
}

/// A call's arguments, each as a failure message shows it.
protocol DescribedArguments {
    /// One per argument: a subscript setter's new value comes last.
    var argumentDescriptions: [String] { get }
    /// A property setter's new value, a tuple in its parentheses.
    var valueDescription: String { get }
}

extension ConcreteStubCall: DescribedArguments {
    var argumentDescriptions: [String] {
        let mirror = Mirror(reflecting: parameters)
        guard mirror.displayStyle == .tuple else {
            return [Self.describe(parameters)]
        }
        return mirror.children.map { Self.describe($0.value) }
    }

    var valueDescription: String {
        Mirror(reflecting: parameters).displayStyle == .tuple ? String(describing: parameters) : Self.describe(parameters)
    }

    /// `value` as a tuple's element describes it, so a string gets its quotes.
    private static func describe(_ value: Any) -> String {
        String(String(describing: (value, 0)).dropFirst().dropLast(4))
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
        // A generic method's name is followed by its generic parameters, as in `parse<T: Decodable> (_ p0: String)`;
        // an operator's `<` follows a space or another operator character: `static <(_ p0: Self, _ p1: Self)`.
        guard let (baseName, open) = Self.baseNameAndParameterList(in: method) else {
            name = String(method.prefix { $0 != "#" })
            labels = isSetter ? ["newValue"] : []
            return
        }
        let parameters = Self.topLevelParameters(in: method[method.index(after: open)...])
        let declaredLabels = parameters.map { parameter in
            String(parameter.drop(while: \.isSpace).prefix { $0 != " " && $0 != ":" })
        }
        name = String(baseName) + "(" + declaredLabels.map { $0 + ":" }.joined() + ")"
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

    /// A method's name without its generic parameters, and the parenthesis that opens its parameter list; `nil`
    /// for a property.
    static func baseNameAndParameterList(in method: String) -> (baseName: Substring, open: String.Index)? {
        let genericClause = genericClauseStart(in: method)
        guard let open = genericClause.map({ parameterListStart(in: method, after: $0) }) ?? method.firstIndex(of: "(") else {
            return nil
        }
        return (method[..<(genericClause ?? open)], open)
    }

    /// The `<` that opens a generic method's generic parameters, right after its name, before any parenthesis.
    private static func genericClauseStart(in method: String) -> String.Index? {
        var previous: Character?
        for index in method.indices {
            let character = method[index]
            if character == "(" || character == "#" {
                return nil
            }
            if character == "<", let previous, previous.isLetter || previous.isNumber || previous == "_" || previous == "`" {
                return index
            }
            previous = character
        }
        return nil
    }

    /// The parenthesis that opens the parameter list, after the generic parameters that may follow the name: a
    /// constraint such as `<T: Collection<(Int, Int)>>` has parentheses of its own.
    private static func parameterListStart(in method: String, after nameEnd: String.Index) -> String.Index? {
        var depth = 0
        var previous: Character?
        for index in method[nameEnd...].indices {
            let character = method[index]
            defer { previous = character }
            switch character {
            case "<":
                depth += 1
            case ">" where previous != "-":
                depth -= 1
            case "(" where depth == 0:
                return index
            case "#" where depth == 0:
                return nil
            default:
                break
            }
        }
        return nil
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
                    if !last.allSatisfy(\.isSpace) {
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

private extension Character {
    /// Whitespace other than a line break.
    var isSpace: Bool {
        isWhitespace && !isNewline
    }
}
