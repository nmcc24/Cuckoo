import Cuckoo

// Variadic parameters: the mock keeps the `...`, and records and matches the arguments as an array.
protocol Logger {
    func log(_ items: String...)
    func log(level: Int, _ items: Any..., separator: String) -> Bool
    func sum(_ values: Int...) async throws -> Int
    func first<T: Equatable>(of values: T...) -> T?
    func handlers(_ handlers: (() -> Void)...)
    subscript(_ keys: String...) -> Int { get set }
    static func reset(_ names: String...)
}

protocol LoggerActor: Actor {
    func log(_ items: String...)
}

@MainActor
protocol MainActorLogger {
    func log(_ items: String...)
}

protocol Store {
    associatedtype Item
    func save(_ items: Item...)
    func count(of items: Int...) -> Int
    subscript(_ keys: Item...) -> Int { get }
}

class Printer {
    init() {}
    func print(_ lines: String..., terminator: String = "\n") -> Int { lines.count }
    subscript(_ indices: Int...) -> String { "" }
}

func useVariadicMocks(_ logger: MockLogger, _ printer: MockPrinter) {
    stub(logger) { stub in
        when(stub.log(any())).thenDoNothing()
        when(stub.log(level: 1, any(), separator: " ")).thenReturn(true)
        when(stub.sum(equal(to: [1, 2]))).thenReturn(3)
        when(stub.first(of: equal(to: [1, 2]))).thenReturn(1)
        when(stub[equal(to: ["a", "b"])].get).thenReturn(2)
    }
    stub(printer) { stub in
        when(stub.print(equal(to: ["a"]), terminator: any())).thenReturn(1)
    }
    logger.log("a", "b")
    _ = logger.log(level: 1, 1, "two", separator: " ")
    _ = logger.first(of: 1, 2)
    _ = logger["a", "b"]
    _ = printer.print("a", terminator: "\n")
    verify(logger).log(equal(to: ["a", "b"]))
    verify(printer).print(equal(to: ["a"]), terminator: "\n")
}
