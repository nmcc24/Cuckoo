import Testing
@testable import CuckooGenerator

/// The default a mock builds itself for an unstubbed call: which return types get one, and what it names.
@Suite
struct GeneratedDefaultsTests {
    /// The defaults the mocks of `source` pass, in order.
    private func defaults(in source: String, moduleKeys: String = "", options: String = "") async throws -> [String] {
        let argument = "unstubbedTuple: "
        return try await generateMocks(source: source, moduleKeys: moduleKeys, options: options).lines
            .map(\.trimmed)
            .filter { $0.hasPrefix(argument) && !$0.hasSuffix("{") }
            .map { String($0.dropFirst(argument.count)) }
    }

    @Test(arguments: [
        ("Engine", "Engine", false),
        ("any Engine", "Engine", true),
        ("any Feature.Engine", "Feature.Engine", true),
        ("Feature . Engine", "Feature.Engine", false),
    ])
    func plainNamesAreRead(type: String, name: String, isExistential: Bool) throws {
        let parsed = try #require(GeneratedDefaults.typeName(type))
        #expect(parsed.name == name)
        #expect(parsed.isExistential == isExistential)
    }

    @Test(arguments: [
        "Engine?", "[Engine]", "any Engine & Sendable", "Box<Engine>", "any Shelf<Int>", "some Engine", "Engine.Type",
        "any Engine.Type", "(Engine, Int)", "`Engine`", "Outer<Int>.Engine", "() -> Engine", "",
    ])
    func otherTypesHaveNoPlainName(type: String) {
        #expect(GeneratedDefaults.typeName(type) == nil)
    }

    @Test
    func anExistentialOfAMockedProtocolGetsItsStub() async throws {
        let source = """
            protocol Engine {}
            protocol Car {
                var engine: any Engine { get }
                func bare() -> Engine
                func parenthesized() -> (any Engine)
                func optional() -> (any Engine)?
                func unwrapped() -> (any Engine)!
                func list() -> [any Engine]
                func composed() -> any Engine & Sendable
                func other() -> any Error
                subscript(index: Int) -> any Engine { get }
            }
            class Workshop {
                func engine() -> any Engine { fatalError() }
            }
            """
        #expect(try await defaults(in: source) == Array(repeating: "EngineStub()", count: 5))
    }

    /// A protocol the module doesn't mock has no stub.
    @Test
    func anUnmockedProtocolGetsNone() async throws {
        let source = """
            protocol Engine {}
            protocol Car {
                func engine() -> any Engine
            }
            """
        #expect(try await defaults(in: source, moduleKeys: #"exclude = ["Engine"]"#).isEmpty)
        #expect(try await defaults(in: source, moduleKeys: #"regex = "Car""#).isEmpty)
    }

    /// `Stub()` has to compile wherever the mock is.
    @Test(arguments: [
        "protocol Engine { associatedtype Fuel }",
        "protocol Engine<Fuel> { associatedtype Fuel }",
        "protocol Engine { init(power: Int) }",
        "protocol Engine { init() }",
        "class Base {}\nprotocol Engine: Base {}",
        "@available(*, deprecated)\nprotocol Engine {}",
        "#if DEBUG\nprotocol Engine {}\n#endif",
    ])
    func aStubThatInitCannotAlwaysCreateIsLeftOut(engine: String) async throws {
        let source = """
            \(engine)
            protocol Car {
                func engine() -> any Engine
            }
            """
        #expect(try await defaults(in: source).isEmpty)
    }

    /// A name is the declaration Swift finds from the member's scope.
    @Test
    func namesResolveByScope() async throws {
        let source = """
            protocol Engine {}
            typealias Motor = Engine
            enum Feature {
                protocol Engine {}
                protocol Car {
                    func nearest() -> any Engine
                    func aliased() -> any Motor
                    func qualified() -> any Feature.Engine
                    func module() -> any App.Feature.Engine
                }
                enum Hidden {
                    struct Engine {}
                    protocol Car {
                        func shadowed() -> Engine
                    }
                }
            }
            protocol Car {
                associatedtype Motor
                func outer() -> any Engine
                func module() -> any App.Engine
                func nested() -> any Feature.Engine
                func associated() -> Motor
                func generic<Engine>(_ engine: Engine) -> Engine
            }
            """
        #expect(try await defaults(in: source) == [
            "Feature.EngineStub()", "EngineStub()", "Feature.EngineStub()", "Feature.EngineStub()",
            "EngineStub()", "EngineStub()", "Feature.EngineStub()",
        ])
    }
}
