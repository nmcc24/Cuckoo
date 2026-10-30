/// Generic methods whose types use `Output`, a non-primary associated type, only in their return type.
protocol Labeler<Input> {
    associatedtype Input
    associatedtype Output

    func label<T>(_ value: T) -> Output
    func labels<T>(_ values: [T]) -> [Output]
    func pair<T>(_ value: T, input: Input) -> (Output, T)
    func lookup<T>(_ key: T) async throws -> Output?
}
