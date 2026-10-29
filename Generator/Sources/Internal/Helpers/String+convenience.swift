import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

extension String {
    subscript(range: NSRange) -> String {
        let fromIndex = self.index(self.startIndex, offsetBy: range.location)
        let toIndex = self.index(fromIndex, offsetBy: range.length)
        return String(self[fromIndex..<toIndex])
    }
}

extension String {
    func stringMatch(from match: NSTextCheckingResult, at range: Int = 0) -> String {
        let matchRange = match.range(at: range)
        let fromIndex = index(startIndex, offsetBy: matchRange.location)
        let toIndex = index(fromIndex, offsetBy: matchRange.length)
        return String(self[fromIndex..<toIndex])
    }

    func removing(match: NSTextCheckingResult, at range: Int = 0) -> String {
        let matchRange = match.range(at: range)
        let fromIndex = index(startIndex, offsetBy: matchRange.location)
        let toIndex = index(fromIndex, offsetBy: matchRange.length)

        var mutableString = self
        mutableString.removeSubrange(fromIndex..<toIndex)
        return mutableString
    }
}

extension String {
    /// A type written as `Parent<String, Int>`, without its generic arguments: `Parent`.
    var withoutGenericArguments: String {
        guard let openingBracket = firstIndex(of: "<") else { return self }
        return String(self[..<openingBracket]).trimmingCharacters(in: .whitespaces)
    }

    /// A type's top-level generic arguments: `["String", "[Int: Bool]"]` for `Parent<String, [Int: Bool]>`.
    var genericArguments: [String] {
        guard let openingBracket = firstIndex(of: "<"), hasSuffix(">") else { return [] }
        var arguments: [String] = []
        var current = ""
        var depth = 0
        for character in self[index(after: openingBracket)..<index(before: endIndex)] {
            switch character {
            case "<", "[", "(":
                depth += 1
            case ">", "]", ")":
                depth -= 1
            case "," where depth == 0:
                arguments.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                continue
            default:
                break
            }
            current.append(character)
        }
        arguments.append(current.trimmingCharacters(in: .whitespaces))
        return arguments
    }
}
