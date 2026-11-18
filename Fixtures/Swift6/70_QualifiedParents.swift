import Foundation

// A parent written with its module's name, as `Swift.Error`, is declared outside the sources even when a type of
// the sources has its name: resolving it to the type itself sent the generator into endless recursion.
protocol Error: Swift.Error {
    var code: Int { get }
}

#if canImport(ObjectiveC)
// `nonisolated`, so it keeps Foundation's nonisolated `init()` under default MainActor isolation. Linux's
// Foundation can't be subclassed from another module.
nonisolated class Thread: Foundation.Thread {
    func extra() {}
}
#endif

enum Net {
    protocol Error: Swift.Error {
        var code: Int { get }
    }
}

protocol Failure: Net.Error {
    var reason: String { get }
}
