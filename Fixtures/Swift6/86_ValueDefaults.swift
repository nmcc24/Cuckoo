// An unstubbed call returning one of the sources' own types answers with a value the mock builds: `Type()` where
// an initializer takes no arguments, or an enum's first case without associated values.

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
final class Screen {
    var title = ""
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
struct Modern {
    var value = 0
}

class Sheet: Document {}

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
    func canvas() -> Canvas
    func document() -> Document
    func counter() -> Counter
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
    func modern() -> Modern
    func sheet() -> Sheet
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
    func canvas() -> Canvas
    func direction() async -> Direction
}

protocol Vault: Actor {
    func settings() -> Settings
    func canvas() -> Canvas
    func outcome() -> Outcome
}

class Studio {
    init() {}

    var direction: Direction { fatalError() }

    func settings() -> Settings { fatalError() }
    func canvas(named name: String) -> Canvas { fatalError() }
}
