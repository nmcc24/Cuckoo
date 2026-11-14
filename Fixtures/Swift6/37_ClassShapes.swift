// Class mocks: a `where` clause on the class, default parameter values (a call through the mock's type can still
// leave them out), members with an opaque `some` type, which an override can't repeat and the mock skips with a
// comment, keyword labels, a label named like the mock's own parameter names, generic parameters named like the
// proxies' matcher generics, unannotated properties whose type the generator can infer, and a class nested in an
// actor, which the module's default isolation doesn't reach.
protocol ShapeProtocol {}
struct ShapeBox: ShapeProtocol {}
enum ShapeLevel { case info, debug }

class WhereBox<T: Hashable, U> where U: Sendable {
    init() {}
    func put(_ value: U) {}
}

class ShapePrinter {
    static let defaultCount = 2
    init() {}
    func print(_ text: String, terminator: String = "\n") {}
    func count(level: ShapeLevel = .info, times: Int = defaultCount, tags: [String] = []) -> Int { times }
    var body: some ShapeProtocol { ShapeBox() }
    func make() -> some ShapeProtocol { ShapeBox() }
    func `default`(`in` value: Int) {}
    func labelled(p0: Int, p1 other: String) {}
    func generic<M1: Equatable>(_ value: M1, count: Int) -> M1 { value }
    var items = Array(repeating: 0, count: 3)
    var list = [1, 2]
    var table = ["a": 1]
}

func useDefaults(_ printer: MockShapePrinter) -> Int {
    printer.print("text")
    return printer.count()
}

actor ShapeStore {
    class Cache {
        init() {}
        func clear() {}
    }
}
