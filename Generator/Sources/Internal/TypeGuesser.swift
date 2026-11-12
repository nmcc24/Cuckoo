import SwiftSyntax

/// The type of a stored property with no annotation, read from its initializer when the initializer names it.
/// Anything else is `nil`, so the property gets the "add a type annotation" warning instead of a wrong type that
/// makes the mock fail to compile.
enum TypeGuesser {
    static func guessType(from initializer: ExprSyntax) -> String? {
        if let literal = literalType(of: initializer) {
            return literal
        }
        if let cast = castType(of: initializer) {
            return cast
        }
        if let call = initializer.as(FunctionCallExprSyntax.self) {
            return initializedType(by: call.calledExpression)
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
