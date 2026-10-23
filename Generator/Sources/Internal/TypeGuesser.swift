import Foundation

struct TypeGuesser {
    static func guessType(from value: String) -> String? {
        guard !value.trimmed.isEmpty else { return nil }
        let value = value.trimmed
        guard !value.isEmpty else { return nil }

        let casting = checkCasting(from: value)
        guard casting == nil else { return casting }

        let character = value[value.startIndex]
        switch character {
        case "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
            return guessNumberType(from: value)
        case "_":
            return guessIdentifier(from: value)
        case "\"":
            return "String"
        default:
            guard let identifier = guessIdentifier(from: value) else { return nil }
            if identifier == "true" || identifier == "false" {
                return "Bool"
            }
            // Only `TypeName(...)` initializers name their type. A function call, a collection literal
            // or `.init()` doesn't, and guessing would produce a mock that doesn't compile.
            return identifier.first?.isUppercase == true ? identifier : nil
        }
    }

    private static func guessNumberType(from value: String) -> String {
        var iterator = value.makeIterator()
        while let character = iterator.next() {
            if character == "." || character == "e" {
                return "Double"
            }
        }
        return "Int"
    }

    private static func guessIdentifier(from value: String) -> String? {
        var identifier = ""
        var iterator = value.makeIterator()
        while let character = iterator.next() {
            guard character != "(" else { break }
            identifier.append(character)
        }
        return identifier.nilIfEmpty
    }

    private static func checkCasting(from value: String) -> String? {
        let regex = try! NSRegularExpression(pattern: " as (.*)$")
        let range = NSRange(location: 0, length: value.count)
        guard let casting = regex.firstMatch(in: value, range: range) else { return nil }
        let foundRange = casting.range(at: 1)
        guard foundRange.location != NSNotFound else { return nil }
        return value[foundRange]
    }
}
