struct Wrapper {
    struct Output {}
}

protocol Converter<Input> {
    associatedtype Input
    associatedtype Output

    func convert<T>(value: T) -> Output
    func convert(input: Input) -> Output
    func wrap<T>(_ value: T) -> [Output]
    func pair<T>(_ value: T, input: Input) -> (Output, T)
    func merge<T>(_ value: T, into output: Output) -> Output
    func lookup<T>(_ key: T) -> Output?
    func collect<T>(_ outputs: [Output], tag: T) -> [String: Output]
    func result<T>(_ value: T) -> Result<Output, any Error>
    func nested<T>(_ value: T) -> Wrapper.Output
}

protocol Producer {
    associatedtype Output

    func produce<T>(from value: T) -> Output
    func consume<T>(_ output: Output, with value: T)
    func produceAll<T>(from values: [T]) async throws -> [Output]
}
