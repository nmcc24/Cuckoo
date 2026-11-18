/// Types of the sources a mock can build a value of, for a call that returns one without a stub.
struct Preferences: Equatable {
    var volume = 5
    var label: String?
}

final class Sketch {
    var strokes: [String] = []
}

enum Heading {
    case north, south
}

enum Progress: Equatable {
    case failed(code: Int)
    case idle
    case done
}

/// Members returning the sources' own types, which have no registered default value.
protocol Console {
    var preferences: Preferences { get }
    func sketch() -> Sketch
    func heading() -> Heading
    func progress() async -> Progress
    func optionalPreferences() -> Preferences?
    func headings() -> [Heading]
}

class Cabinet {
    func preferences() -> Preferences {
        fatalError("Mocked in the tests.")
    }

    func heading() -> Heading {
        fatalError("Mocked in the tests.")
    }
}
