import Foundation

protocol SubscriptProtocol {
    subscript(key: String) -> Int? { get set }
    subscript(index: Int) -> String { get }
    subscript(row row: Int, column column: Int) -> Double { get set }
    subscript(failable key: String) -> Int { get throws }
    subscript(remote key: String) -> String { get async }
    subscript<T: Equatable>(echo value: T) -> T { get }
    subscript() -> Int { get set }

    func sum(_ values: some Collection<Int>) -> Int
}

class SubscriptClass {
    private var storage: [String: Int] = [:]

    subscript(key: String) -> Int {
        get {
            storage[key] ?? 0
        }
        set {
            storage[key] = newValue
        }
    }

    subscript(index: Int) -> String {
        "\(index)"
    }
}

protocol GenericSubscriptProtocol<Value> {
    associatedtype Value

    subscript(key: String) -> Value { get set }
    subscript(index index: Int) -> Value? { get }
}

final class GenericSubscriptImplementation<Value>: GenericSubscriptProtocol {
    private var storage: [String: Value] = [:]

    subscript(key: String) -> Value {
        get {
            storage[key]!
        }
        set {
            storage[key] = newValue
        }
    }

    subscript(index index: Int) -> Value? {
        storage.values.first
    }

    init(_ storage: [String: Value]) {
        self.storage = storage
    }
}
