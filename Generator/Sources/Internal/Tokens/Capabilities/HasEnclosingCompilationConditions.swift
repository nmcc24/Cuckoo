/// A type whose whole declaration can sit inside `#if` blocks.
protocol HasEnclosingCompilationConditions: Token {
    /// The conditions of the `#if` blocks around the declaration, including those around its enclosing types.
    /// Everything generated for the type is wrapped in them.
    var enclosingCompilationConditions: [String] { get }
}

extension HasEnclosingCompilationConditions {
    func enclosingCompilationConditionsSerialize() -> GeneratorContext {
        [
            "hasEnclosingCompilationCondition": !enclosingCompilationConditions.isEmpty,
            "enclosingCompilationConditionCheck": "#if \(enclosingCompilationConditions.joined(separator: " && "))",
        ]
    }
}
