// Return and property types naming closures whose parameters have specifiers, which `(type).self` can't spell: the
// Stub class and a tuple's unstubbed default name them through a local typealias.
final class Token {}

protocol SpecifierClosures {
    var borrowingHandler: (borrowing Token) -> Void { get }
    func consumingHandler() -> (consuming Token) -> Void
    func isolatedHandler() -> (isolated any Actor) -> Void
    func sendingHandler() -> (sending Token) -> sending Token
    func ownedHandler() -> (__owned Token, __shared Token) -> Void
    func pair() -> (count: Int, handler: (borrowing Token) -> Void)
    func made() -> sending Token
    subscript(index: Int) -> (consuming Token) -> Int { get }
}

class SpecifierClosureService {
    init() {}
    func handler() -> (borrowing Token) -> Void { { _ in } }
    var pair: (Int, (consuming Token) -> Void) { (0, { _ in }) }
}
