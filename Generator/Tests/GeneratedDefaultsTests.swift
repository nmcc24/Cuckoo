import Testing
@testable import CuckooGenerator

/// The default a mock builds itself for an unstubbed call: which return types get one, and what it names.
@Suite
struct GeneratedDefaultsTests {
    /// The defaults the mocks of `source` pass, in order.
    private func defaults(
        in source: String,
        sources: String = #"["Source.swift"]"#,
        moduleKeys: String = "",
        options: String = ""
    ) async throws -> [String] {
        let argument = "unstubbedDefault: "
        return try await generateMocks(source: source, sources: sources, moduleKeys: moduleKeys, options: options).lines
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
            // `aliased()` has none: inside `Feature`, `EngineStub` is the stub of `Feature.Engine`.
            "Feature.EngineStub()", "Feature.EngineStub()", "Feature.EngineStub()",
            // The struct nearest to the member, not a protocol further out.
            "Engine()",
            "EngineStub()", "EngineStub()", "Feature.EngineStub()",
        ])
    }

    @Test
    func aTypeOfTheSourcesGetsAValue() async throws {
        let source = """
            struct Settings { var volume = 5 }
            struct Canvas {}
            final class Sheet {}
            actor Counter {}
            enum Direction { case north, south }
            enum Feature {
                struct Flags {}
            }
            struct Token { let value: String }
            protocol Desk {
                var settings: Settings { get }
                func canvas() -> Canvas
                func direction() -> Direction
                func flags() -> Feature.Flags
                func qualified() -> App.Settings
                func token() -> Token
                func optional() -> Settings?
                func list() -> [Direction]
                func existential() -> any Settings
                func generic<Canvas>(_ canvas: Canvas) -> Canvas
                func foreign() -> Data
                func sheet() -> Sheet
                func counter() -> Counter
            }
            class Studio {
                func settings() -> Settings { Settings() }
            }
            """
        #expect(try await defaults(in: source) == [
            "Settings()", "Canvas()", "Direction.north", "Feature.Flags()", "App.Settings()", "Settings()",
        ])
    }

    /// With an initializer in an extension, `Type()` may be ambiguous, or not the initializer the type declares.
    @Test
    func aStructWithAnExtensionInitializerGetsNone() async throws {
        let source = """
            struct Range {
                init(maximum: Int = 3) {}
            }
            extension Range {
                init(minimum: Int = 0) {}
            }
            enum Feature {
                struct Limits {}
                struct Flags {}
            }
            extension App.Feature.Limits {
                init(maximum: Int) {}
            }
            protocol Desk {
                func range() -> Range
                func limits() -> Feature.Limits
                func flags() -> Feature.Flags
            }
            """
        #expect(try await defaults(in: source) == ["Feature.Flags()"])
    }

    /// A name qualified with a module that isn't the sources' is that module's type, whatever the sources declare.
    @Test
    func aTypeOfAnotherModuleIsNotTheSourcesTypeOfThatName() async throws {
        let source = """
            import Foundation
            struct Notification {}
            enum Locale { case english }
            protocol Engine {}
            enum Feature {
                struct Flags {}
            }
            protocol Desk {
                func foreign() -> Foundation.Notification
                func foreignLocale() -> Foundation.Locale
                func foreignEngine() -> any Vendor.Engine
                func foreignNested() -> Vendor.Feature.Flags
                func own() -> Notification
                func ownLocale() -> App.Locale
                func ownEngine() -> any App.Engine
                func ownNested() -> App.Feature.Flags
            }
            """
        #expect(try await defaults(in: source) == ["Notification()", "App.Locale.english", "EngineStub()", "App.Feature.Flags()"])
        // The Swift module of the sources, where the Cuckoofile names it, qualifies them too.
        let inCore = #"{ Core = ["Source.swift"] }"#
        let core = source.replacing("Vendor.", with: "Core.")
        #expect(try await defaults(in: core, sources: inCore, moduleKeys: #"testableImports = ["Core"]"#) == [
            "EngineStub()", "Core.Feature.Flags()", "Notification()", "App.Locale.english", "EngineStub()", "App.Feature.Flags()",
        ])
    }

    /// A stub is named from the top level, so a declaration of that name nearer to the mock would be found instead.
    @Test
    func aShadowedStubIsLeftOut() async throws {
        let source = """
            protocol Engine {}
            protocol Wheel {}
            typealias Motor = Engine
            enum Feature {
                protocol Engine {}
                struct WheelStub {}
                protocol Car {
                    func aliased() -> any Motor
                    func qualified() -> any App.Engine
                    func wheel() -> any Wheel
                    func nearest() -> any Engine
                }
            }
            class Workshop {
                protocol Engine {}
                func aliased() -> any Motor { fatalError() }
            }
            protocol Car {
                func engine() -> any Motor
                func wheel() -> any Wheel
            }
            """
        #expect(try await defaults(in: source) == ["Feature.EngineStub()", "EngineStub()", "WheelStub()"])
    }

    /// An internal initializer, an implicit one included, is the mocks' to call only with the module's internals in
    /// sight: in the mock of an internal type, or when the Cuckoofile imports the sources' module with `@testable`.
    @Test
    func anInternalInitializerNeedsTheModulesInternals() async throws {
        let source = """
            public struct Summary { public var total = 0 }
            public struct Report { public init() {} }
            public enum Level { case low }
            public protocol Kiosk {
                func summary() -> Summary
                func report() -> Report
                func level() -> Level
            }
            protocol Desk {
                func summary() -> Summary
            }
            """
        #expect(try await defaults(in: source) == ["Report()", "Level.low", "Summary()"])

        // The table form of `sources` names the file's Swift module.
        let inApp = #"{ App = ["Source.swift"] }"#
        #expect(try await defaults(in: source, sources: inApp, moduleKeys: #"testableImports = ["App"]"#) == ["Summary()", "Report()", "Level.low", "Summary()"])
        #expect(try await defaults(in: source, sources: inApp, moduleKeys: #"imports = ["App"]"#) == ["Report()", "Level.low"])
    }

    /// Under a default isolation, a type's initializer runs on that actor, which a mock's member may not.
    @Test
    func aDefaultIsolationLeavesOnlyEnumCases() async throws {
        let source = """
            struct Settings {}
            enum Direction { case north }
            protocol Desk {
                func settings() -> Settings
                func direction() -> Direction
            }
            """
        #expect(try await defaults(in: source, options: #"defaultIsolation = "MainActor""#) == ["Direction.north"])
        #expect(try await defaults(in: source, options: #"defaultIsolation = "nonisolated""#) == ["Settings()", "Direction.north"])
    }

    /// A type gets a value only when its name is one declaration, nested in the sources' own non-generic types.
    @Test
    func anAmbiguousTypeGetsNone() async throws {
        let source = """
            #if os(macOS)
            struct Settings {}
            #endif
            struct Settings { var volume: Int }
            struct Box<Value> {}
            extension Box {
                struct Lid {}
            }
            extension Array {
                struct Slot {}
            }
            struct Outer {
                struct Settings {}
            }
            extension Outer {
                protocol Desk {
                    func settings() -> Settings
                }
            }
            protocol Desk {
                func settings() -> Settings
                func lid() -> Box<Int>.Lid
                func slot() -> Array<Int>.Slot
                func nested() -> Outer.Settings
            }
            """
        #expect(try await defaults(in: source) == ["Settings()", "Outer.Settings()"])
    }
}
