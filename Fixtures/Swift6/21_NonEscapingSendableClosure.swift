protocol Transformer {
    func transform(_ body: @Sendable (String) async -> String?) -> String?
    func transformAsync(_ body: @Sendable (String) -> String?) async -> String?
    func forEach(_ body: @Sendable (Int, String) -> Void)
}

class TransformingService {
    func transform(_ body: @Sendable (String) async -> String?) -> String? { nil }
    func transformAsync(_ body: @Sendable (String) -> String?) async -> String? { nil }
}
