/// Variadic parameters, which a mock records as the array the function receives.
protocol VariadicLogger {
    func log(_ messages: String..., level: Int) -> Int
    func sum(_ values: Int...) async throws -> Int
}

class VariadicFormatter {
    func join(_ parts: String..., separator: String) -> String {
        parts.joined(separator: separator)
    }
}
