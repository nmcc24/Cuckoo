protocol Configurable {
    init<T>(value: T)
    init<C: Collection>(items: C) where C.Element == Int
    init?<T: Equatable>(maybe: T)
    func describe() -> String
}

class Box {
    let label: String
    init<T>(value: T) { label = "\(value)" }
    init<T: CustomStringConvertible>(described: T) { label = described.description }
    required init<T: Hashable>(key: T) { label = "\(key.hashValue)" }
    convenience init<S: Sequence>(contents: S) where S.Element == String {
        self.init(value: Array(contents).joined())
    }
    func label(prefix: String) -> String { prefix + label }
}
