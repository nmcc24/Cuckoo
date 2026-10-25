import Foundation

protocol StaticFactory {
    static var count: Int { get set }
    static var name: String { get }
    static subscript(key: String) -> Int { get }

    static func make() -> Self
    static func load(id: Int) async throws -> String

    func build() -> Int
}

class StaticMembersClass {
    class var version: Int {
        1
    }

    class func describe(_ value: Int) -> String {
        "real \(value)"
    }

    /// `static` in a class is final, so it isn't mocked.
    static func notMocked() -> Int {
        0
    }

    func instanceValue() -> Int {
        2
    }
}

protocol GenericStaticFactory<Product> {
    associatedtype Product

    static func make() -> Product
    func use(_ product: Product)
}
