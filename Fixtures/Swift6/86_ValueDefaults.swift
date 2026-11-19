// An unstubbed call returning one of the sources' own structs or enums answers with a value the mock builds:
// `Type()` where a struct's initializer takes no arguments, or an enum's first case without associated values.
// `Fix`, the module the fixture matrix compiles this as, qualifies a type only there.

import Foundation

struct Settings {
    var volume = 5
    var label: String?
    static let shared = Settings()
    var isLoud: Bool { volume > 7 }
}

struct Options: Sendable, Equatable {
    let retries: Int

    init(retries: Int = 3) {
        self.retries = retries
    }
}

public struct Report {
    public var lines: [String]

    public init() {
        lines = []
    }
}

enum Direction {
    case north, south
}

enum Outcome {
    case failed(code: Int)
    case pending
    case done
}

enum Feature {
    struct Flags {
        var isOn = false
    }

    enum Stage {
        case alpha
    }
}

extension Feature {
    struct Limits {
        var maximum = 10
    }
}

// The sources' own `Locale` has a default; `Foundation.Locale`, which a member names with its module, isn't it.
struct Locale {
    var code = ""
}

// No default: a class's or an actor's initializer may do anything, so a mock doesn't run it.
final class Canvas {
    var strokes: [String] = []
}

class Document {
    var title: String

    init() {
        title = ""
    }
}

actor Counter {
    var count = 0
}

// No default: nothing says `Type()` compiles, or runs from any isolation, wherever the mock does.
struct Coordinates {
    var x: Double
    var y: Double
}

struct Token {
    let value: String

    init(value: String) {
        self.value = value
    }
}

struct Secret {
    private init() {}
}

struct Parsed {
    init?() {
        return nil
    }
}

struct Loaded {
    init() throws {}
}

struct Box<Value> {
    var value: Value?
}

@MainActor
struct Screen {
    var title = ""
}

// An initializer in an extension can make `Type()` ambiguous.
struct Range {
    let minimum: Int
    let maximum: Int

    init(maximum: Int = 3) {
        minimum = 0
        self.maximum = maximum
    }
}

extension Range {
    init(minimum: Int = 0) {
        self.minimum = minimum
        maximum = 3
    }
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
struct Modern {
    var value = 0
}

struct Wrapped {
    @Clamped var level: Int
}

@propertyWrapper
struct Clamped {
    var wrappedValue: Int

    init(wrappedValue: Int) {
        self.wrappedValue = wrappedValue
    }
}

#if DEBUG
struct Probe {
    var count = 0
}
#endif

enum Payload {
    case data(Int)
}

protocol Desk {
    var settings: Settings { get }
    var direction: Direction { get set }
    func options() -> Options
    func report() -> Report
    func outcome() -> Outcome
    func flags() -> Feature.Flags
    func stage() -> Feature.Stage
    func limits() -> Feature.Limits
    func qualified() -> Fix.Settings
    func later() async -> Settings
    func failing() throws -> Settings
    subscript(index: Int) -> Direction { get }
    static func make() -> Settings

    // These keep the defaults they had, or none.
    func optional() -> Settings?
    func list() -> [Settings]
    func pair() -> (Settings, Direction)
    func coordinates() -> Coordinates
    func token() -> Token
    func secret() -> Secret
    func parsed() -> Parsed
    func loaded() -> Loaded
    func box() -> Box<Int>
    func screen() -> Screen
    func range() -> Range
    func modern() -> Modern
    func canvas() -> Canvas
    func document() -> Document
    func counter() -> Counter
    func locale() -> Locale
    func foreignLocale() -> Foundation.Locale
    func wrapped() -> Wrapped
    func payload() -> Payload
    func generic<Settings>(_ value: Settings) -> Settings
    #if DEBUG
    func probe() -> Probe
    #endif
}

// A public mock sees an internal initializer, such as an implicit one, only through `@testable`, which nothing here
// promises.
public struct Summary {
    public var total = 0
}

public protocol Kiosk {
    func report() -> Report
    func summary() -> Summary
}

@MainActor
protocol Panel {
    var settings: Settings { get }
    func options() -> Options
    func direction() async -> Direction
}

protocol Vault: Actor {
    func settings() -> Settings
    func outcome() -> Outcome
}

class Studio {
    init() {}

    var direction: Direction { fatalError() }

    func settings() -> Settings { fatalError() }
    func limits(named name: String) -> Feature.Limits { fatalError() }
}
