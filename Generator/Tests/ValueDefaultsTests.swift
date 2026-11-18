import Testing
@testable import CuckooGenerator

/// Which of the sources' types a mock can build a value of, read from their declarations.
@Suite
struct ValueDefaultsTests {
    private func value(of name: String = "Value", in source: String) -> ValueDefault? {
        Crawler.valueDefaults(in: source).defaults[name]
    }

    @Test(arguments: [
        "struct Value {}",
        "struct Value { var count = 0; let name = \"\"; var note: String?; var forced: Int! }",
        "struct Value { static let shared = Value(); var isEmpty: Bool { true }; var count = 0 { didSet {} } }",
        "struct Value { lazy var cache = [Int](); @Clamped var level = 1 }",
        "struct Value: Sendable, Hashable { var count = 0 }",
        "final class Value { var count = 0 }",
        "class Value: NSObject, @unchecked Sendable { var count = 0 }",
        "actor Value { var count = 0 }",
        "@frozen struct Value { var count = 0 }",
        "struct Value { var count: Int\n init() { count = 0 } }",
        "struct Value { var count: Int\n nonisolated init() { count = 0 }\n init(count: Int) { self.count = count } }",
        "struct Value { var count: Int\n init(count: Int = 0) { self.count = count } }",
        "class Value { let count: Int\n required convenience init() { self.init(count: 0) }\n init(count: Int) { self.count = count } }",
    ])
    func aTypeWithAnInitializerWithoutArgumentsIsBuiltWithIt(source: String) {
        #expect(value(in: source) == .initializer(access: .internal))
    }

    @Test
    func anInitializerKeepsItsAccess() {
        #expect(value(in: "public struct Value { public init() {} }") == .initializer(access: .public))
        #expect(value(in: "public struct Value { package init() {} }") == .initializer(access: .package))
        #expect(value(in: "public struct Value { public var count = 0 }") == .initializer(access: .internal))
    }

    @Test(arguments: [
        // A stored property without a default.
        "struct Value { var count: Int }",
        "struct Value { let note: String? }",
        "struct Value { var count = 0, name: String }",
        "struct Value { @Clamped var level: Int }",
        // No initializer that takes no arguments, or none that's sure to run.
        "struct Value { init(count: Int) {} }",
        "struct Value { private init() {} }",
        "struct Value { fileprivate init() {} }",
        "struct Value { init?() {} }",
        "struct Value { init() throws {} }",
        "actor Value { init() async {} }",
        "struct Value { @MainActor init() {} }",
        "struct Value { @available(*, deprecated) init() {} }",
        "struct Value { init(count: Int = 0) {}\n init(name: String = \"\") {} }",
        "struct Value { init?() {}\n init(count: Int = 0) {} }",
        // The type may be isolated, unavailable or absent, or get its initializers elsewhere.
        "@MainActor struct Value {}",
        "@available(macOS 99, *) struct Value {}",
        "@Observable final class Value {}",
        "struct Value<Element> {}",
        "struct Value: ~Copyable {}",
        "class Value: Base {}",
        "struct Value: Service {}",
        "struct Value {\n #if DEBUG\n var count: Int\n #endif\n }",
        "struct Value { #Preview }",
        "#if DEBUG\nstruct Value {}\n#endif",
        "func make() { struct Value {} }",
        "var make: Int { struct Value {}; return 0 }",
        "let make = { struct Value {} }",
        "protocol Value {}",
    ])
    func aTypeWithoutASureInitializerHasNoDefault(source: String) {
        #expect(value(in: source) == nil)
    }

    @Test(arguments: [
        ("enum Value { case first, second }", "first"),
        ("enum Value { case loaded(Int), failed(code: Int), idle, done }", "idle"),
        ("enum Value { case loaded(Int)\n case idle }", "idle"),
        ("enum Value: String, CaseIterable { case first = \"1\" }", "first"),
        ("indirect enum Value { case leaf, node(Value) }", "leaf"),
        ("enum Value { @available(*, deprecated) case old\n case new }", "new"),
        ("enum Value {\n #if DEBUG\n case debug\n #endif\n case release }", "release"),
        ("enum Value { case `default`, other }", "`default`"),
        ("enum Value: Service { case first }", "first"),
    ])
    func anEnumIsItsFirstCaseWithoutAssociatedValues(source: String, name: String) {
        #expect(value(in: source) == .enumCase(name))
    }

    @Test(arguments: [
        "enum Value {}",
        "enum Value { case loaded(Int) }",
        "enum Value { static let shared = 1 }",
        "enum Value<Element> { case none }",
        "@MainActor enum Value { case none }",
        "enum Value: ~Copyable { case none }",
        "#if os(macOS)\nenum Value { case mac }\n#else\nenum Value { case other }\n#endif",
    ])
    func anEnumWithoutSuchACaseHasNoDefault(source: String) {
        #expect(value(in: source) == nil)
    }

    @Test
    func nestedTypesAreNamedThroughTheirScopes() {
        let source = """
            enum Feature {
                struct Flags {}
                enum Stage { case alpha }
            }
            extension Feature.Stage {
                struct Detail {}
            }
            struct Box<Value> {
                struct Lid {}
            }
            extension Box where Value == Int {
                struct Label {}
            }
            @MainActor final class Screen {
                struct Layout {}
            }
            """
        let values = Crawler.valueDefaults(in: source)
        #expect(values.defaults == [
            "Feature.Flags": .initializer(access: .internal),
            "Feature.Stage": .enumCase("alpha"),
            "Feature.Stage.Detail": .initializer(access: .internal),
        ])
        #expect(values.declarations.keys.sorted() == [
            "Box", "Box.Label", "Box.Lid", "Feature", "Feature.Flags", "Feature.Stage", "Feature.Stage.Detail", "Screen", "Screen.Layout",
        ])
    }

    @Test
    func aNameDeclaredTwiceIsCountedTwice() {
        var values = Crawler.valueDefaults(in: "struct Value {}")
        values.formUnion(Crawler.valueDefaults(in: "struct Value {}\nenum Other { case one }"))
        #expect(values.declarations == ["Value": 2, "Other": 1])
    }
}
