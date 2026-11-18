// Settable `@objc optional` requirements. Read through the protocol, an optional requirement is an immutable
// optional value, so the mock can't forward its setter to a default implementation: it records a failure instead.
// The getters forward, unwrapping the value.
#if canImport(ObjectiveC)
import Foundation

@objc protocol Configurable {
    @objc optional var count: Int { get set }
    @objc optional var name: String? { get set }
    @objc optional var label: String { get }
    @objc optional subscript(index: Int) -> String { get set }
    @objc optional func refresh()
    var required: Int { get set }
}

final class Configuration: NSObject, Configurable {
    var count = 1
    var required = 2
}

func configure(_ mock: MockConfigurable) -> Int {
    mock.enableDefaultImplementation(Configuration())
    mock.required = 3
    return mock.count + mock.required
}
#endif
