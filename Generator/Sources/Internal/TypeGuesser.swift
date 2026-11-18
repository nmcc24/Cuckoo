import SwiftSyntax

/// The type of a stored property with no annotation, read from its initializer when the initializer names it.
/// Anything else is `nil`, so the property gets the "add a type annotation" warning instead of a wrong type that
/// makes the mock fail to compile.
enum TypeGuesser {
    /// - Parameter functions: the sources' functions and methods with a capitalized name, whose calls initialize
    ///   nothing. One that's also a type's name isn't listed: its call may be the type's initializer.
    static func guessType(from initializer: ExprSyntax, genericTypes: Set<String> = [], functions: Set<String> = []) -> String? {
        if let literal = literalType(of: initializer) {
            return literal
        }
        if let collection = collectionLiteralType(of: initializer, genericTypes: genericTypes) {
            return collection
        }
        if let cast = castType(of: initializer) {
            return cast
        }
        if let call = initializer.as(FunctionCallExprSyntax.self) {
            let callee = call.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text
                ?? call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text
            guard callee.map({ !functions.contains($0) }) ?? true else { return nil }
            return callType(of: call, genericTypes: genericTypes, functions: functions)
        }
        return nil
    }

    /// The standard library's generic types, which a call can't name without its generic arguments as a type.
    private static let standardGenericTypes: Set<String> = [
        "Array", "Set", "Dictionary", "Optional", "Result", "ContiguousArray", "Range", "ClosedRange",
    ]

    /// The type a call initializes. A call to a generic type without generic arguments, `Array(...)` or a user's
    /// `Box(1)`, is guessed only where the arguments settle it; and a labelled call may be a failable initializer,
    /// `URL(string:)` or `Int(_:)`, so only an unlabelled call, or one with labels known to be non-failable, counts.
    private static func callType(of call: FunctionCallExprSyntax, genericTypes: Set<String>, functions: Set<String>) -> String? {
        guard let type = initializedType(by: call.calledExpression) else { return nil }
        let baseName = String(type.prefix { $0 != "<" }.split(separator: ".").last ?? "")
        let isGenericWithoutArguments = !type.contains("<")
            && (standardGenericTypes.contains(baseName) || genericTypes.contains(baseName))
        if isGenericWithoutArguments {
            // `Array(repeating: <literal>, count: n)` is `[Literal]`; anything else needs the type checker.
            if baseName == "Array", call.arguments.count == 2,
               call.arguments.first?.label?.text == "repeating", call.arguments.last?.label?.text == "count",
               let element = call.arguments.first.flatMap({ guessType(from: $0.expression, genericTypes: genericTypes, functions: functions) }) {
                return "[\(element)]"
            }
            return nil
        }
        // A failable initializer's result is optional, which the call doesn't show: `URL(string:)`, or a number or
        // `Bool` made from a string, `Int("3")`. The standard ones are known; a user's own `init?` isn't seen.
        if isFailableStandardInitializer(call, type: baseName) {
            return nil
        }
        return type
    }

    private static let failableInitializerLabels: [String: Set<String>] = [
        "URL": ["string"],
        "UUID": ["uuidString"],
        "Data": ["base64Encoded", "contentsOf"],
        "Decimal": ["string"],
    ]

    private static let numericAndBoolTypes: Set<String> = [
        "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
        "Double", "Float", "CGFloat", "Bool", "Character",
    ]

    /// Whether the call is one of the standard library's or Foundation's failable initializers: a labelled one of
    /// `failableInitializerLabels`, or a number, `Bool` or `Character` made from anything but a number literal.
    private static func isFailableStandardInitializer(_ call: FunctionCallExprSyntax, type: String) -> Bool {
        guard let first = call.arguments.first else { return false }
        if let label = first.label?.text, failableInitializerLabels[type]?.contains(label) == true {
            return true
        }
        if numericAndBoolTypes.contains(type) {
            let literal = literalType(of: first.expression)
            return !(call.arguments.count == 1 && first.label == nil && (literal == "Int" || literal == "Double"))
        }
        return false
    }

    /// `[1, 2]` is `[Int]` and `["a": 1]` is `[String: Int]` when every element is the same kind of literal.
    private static func collectionLiteralType(of expression: ExprSyntax, genericTypes: Set<String>) -> String? {
        if let array = expression.as(ArrayExprSyntax.self), !array.elements.isEmpty {
            let types = Set(array.elements.map { literalType(of: $0.expression) })
            guard types.count == 1, let element = types.first ?? nil else { return nil }
            return "[\(element)]"
        }
        if let dictionary = expression.as(DictionaryExprSyntax.self), case .elements(let elements) = dictionary.content, !elements.isEmpty {
            let keys = Set(elements.map { literalType(of: $0.key) })
            let values = Set(elements.map { literalType(of: $0.value) })
            guard keys.count == 1, values.count == 1, let key = keys.first ?? nil, let value = values.first ?? nil else { return nil }
            return "[\(key): \(value)]"
        }
        return nil
    }

    /// The type of `value as Type`, `value as! Type` or `value as? Type`. The parser leaves operators unfolded,
    /// so the cast is the last two elements of a sequence: a lower-precedence operator before it would apply to the
    /// cast's result, which this doesn't try to work out.
    private static func castType(of expression: ExprSyntax) -> String? {
        guard let elements = expression.as(SequenceExprSyntax.self)?.elements, elements.count == 3,
              let cast = elements.dropFirst().first?.as(UnresolvedAsExprSyntax.self),
              let type = elements.last?.as(TypeExprSyntax.self)?.type.trimmedDescription
        else { return nil }
        return cast.questionOrExclamationMark?.tokenKind == .postfixQuestionMark ? "Optional<\(type)>" : type
    }

    /// The type of a literal, also with a leading `-`.
    private static func literalType(of expression: ExprSyntax) -> String? {
        if let prefix = expression.as(PrefixOperatorExprSyntax.self), prefix.operator.text == "-" {
            return literalType(of: prefix.expression).flatMap { $0 == "Int" || $0 == "Double" ? $0 : nil }
        }
        if expression.is(IntegerLiteralExprSyntax.self) {
            return "Int"
        }
        if expression.is(FloatLiteralExprSyntax.self) {
            return "Double"
        }
        if expression.is(StringLiteralExprSyntax.self) {
            return "String"
        }
        if expression.is(BooleanLiteralExprSyntax.self) {
            return "Bool"
        }
        return nil
    }

    /// The type a call initializes, when the called expression names one: `Retries`, `Outer.Inner`, `Box<Int>`
    /// or `Retries.init`. A function, a method such as `UUID().uuidString` or a static member such as
    /// `Style.default` doesn't.
    private static func initializedType(by calledExpression: ExprSyntax) -> String? {
        if let member = calledExpression.as(MemberAccessExprSyntax.self), member.declName.baseName.tokenKind == .keyword(.`init`) {
            return member.base.flatMap(typeName(of:))
        }
        return typeName(of: calledExpression)
    }

    /// `expression` as a type name, if it reads as one: capitalized names, joined by `.`, with generic arguments.
    private static func typeName(of expression: ExprSyntax) -> String? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text.first?.isUppercase == true ? reference.trimmedDescription : nil
        }
        if let member = expression.as(MemberAccessExprSyntax.self), let base = member.base {
            guard member.declName.baseName.text.first?.isUppercase == true, typeName(of: base) != nil else { return nil }
            return member.trimmedDescription
        }
        if let specialization = expression.as(GenericSpecializationExprSyntax.self) {
            return typeName(of: specialization.expression).map { _ in specialization.trimmedDescription }
        }
        return nil
    }
}
