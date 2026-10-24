protocol Platformed {
    #if os(Linux)
    func onLinux() -> Int
    #elseif canImport(Darwin)
    func onDarwin() -> String
    #else
    func elsewhere()
    #endif
    #if DEBUG
    var debugInfo: String { get }
    #if os(Linux)
    func debugOnLinux()
    #endif
    #endif
    func everywhere()
}

// Generic protocols are mocked through a type-erasing default implementation caller.
protocol PlatformedStore {
    associatedtype Item
    #if DEBUG
    var debugItems: [Item] { get }
    func dump() -> String
    #endif
    func item(at index: Int) -> Item
}

class PlatformedService {
    #if DEBUG
    var verbose = false
    func debugDump() -> String { "" }
    #else
    func releaseOnly() {}
    #endif
    func run() {}
}

// A whole type inside `#if` is mocked inside the same condition, and so is an import that sits in one.
#if canImport(Combine)
import Combine

protocol Publishing {
    func publisher() -> AnyPublisher<Int, Never>
}
#endif

#if DEBUG
class DebugTools {
    func check() {}

    // Nested types are mocked at file scope, so they carry their enclosing type's condition as well.
    #if os(Linux)
    class LinuxProbe {
        func probe() {}
    }
    #endif
}
#endif
