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
        "struct Value: @unchecked Sendable, Codable { var count = 0 }",
        "@frozen struct Value { var count = 0 }",
        "struct Value { var count: Int\n init() { count = 0 } }",
        "struct Value { var count: Int\n nonisolated init() { count = 0 }\n init(count: Int) { self.count = count } }",
        "struct Value { var count: Int\n init(count: Int = 0) { self.count = count } }",
    ])
    func aStructWithAnInitializerWithoutArgumentsIsBuiltWithIt(source: String) {
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
        "struct Value { init() async {} }",
        "struct Value { @MainActor init() {} }",
        "struct Value { @available(*, deprecated) init() {} }",
        "struct Value { init(count: Int = 0) {}\n init(name: String = \"\") {} }",
        "struct Value { init?() {}\n init(count: Int = 0) {} }",
        // The type may be isolated, unavailable or absent, or get its initializers elsewhere.
        "@MainActor struct Value {}",
        "@available(macOS 99, *) struct Value {}",
        "@Observable struct Value {}",
        "struct Value<Element> {}",
        "struct Value: ~Copyable {}",
        "struct Value: Service {}",
        // A class's or an actor's initializer may do anything, so a mock doesn't run it.
        "final class Value { var count = 0 }",
        "class Value { init() {} }",
        "class Value: NSObject { override init() {} }",
        "actor Value { var count = 0 }",
        "distributed actor Value { typealias ActorSystem = LocalTestingDistributedActorSystem }",
        "struct Value {\n #if DEBUG\n var count: Int\n #endif\n }",
        "struct Value { #Preview }",
        "#if DEBUG\nstruct Value {}\n#endif",
        "func make() { struct Value {} }",
        "var make: Int { struct Value {}; return 0 }",
        "let make = { struct Value {} }",
        "protocol Value {}",
    ])
    func aTypeWithoutASureStructInitializerHasNoDefault(source: String) {
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
            final class Canvas {
                struct Stroke {}
            }
            """
        let values = Crawler.valueDefaults(in: source)
        #expect(values.defaults == [
            "Feature.Flags": .initializer(access: .internal),
            "Feature.Stage": .enumCase("alpha"),
            "Feature.Stage.Detail": .initializer(access: .internal),
            "Canvas.Stroke": .initializer(access: .internal),
        ])
        #expect(values.declarations.keys.sorted() == [
            "Box", "Box.Label", "Box.Lid", "Canvas", "Canvas.Stroke", "Feature", "Feature.Flags", "Feature.Stage", "Feature.Stage.Detail", "Screen", "Screen.Layout",
        ])
    }

    /// An initializer in an extension isn't the type's to judge: with another one, `Type()` can be ambiguous.
    @Test
    func extensionInitializersAreListedByTheTypeTheExtensionNames() {
        let source = """
            struct Range { init(maximum: Int = 3) {} }
            extension Range { init(minimum: Int = 0) {} }
            extension Feature.Limits {
                #if DEBUG
                init(debug: Bool) {}
                #endif
            }
            extension Settings { func reset() {} }
            struct Plain { init() {} }
            """
        let values = Crawler.valueDefaults(in: source)
        #expect(values.typesWithExtensionInitializers == ["Range", "Feature.Limits"])
        #expect(values.defaults["Range"] == .initializer(access: .internal))
    }

    @Test
    func aNameDeclaredTwiceIsCountedTwice() {
        var values = Crawler.valueDefaults(in: "struct Value {}")
        values.formUnion(Crawler.valueDefaults(in: "struct Value {}\nenum Other { case one }"))
        #expect(values.declarations == ["Value": 2, "Other": 1])
    }
}
