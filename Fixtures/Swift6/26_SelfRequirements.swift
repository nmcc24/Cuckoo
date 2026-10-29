protocol Duplicable {
    func copy() -> Self
    func merged(with other: Self) -> Self
    func isSame(as other: Self) -> Bool
    func sibling() -> Self?
    func children() -> [Self]
    func indexed() -> [String: Self]
    var parent: Self? { get }
    var next: Self? { get set }
    func visit(_ visitor: (Self) -> Void)
    subscript(index: Int) -> Self { get }
    static func combine(_ first: Self, _ second: Self) -> Self
}

protocol AsyncCloner: Sendable {
    func clone() async throws -> Self
    func compare(with other: Self) async -> Bool
}

@MainActor
protocol MainActorPeer {
    func pair(with other: Self) -> Self
}

protocol Stack<Element> {
    associatedtype Element
    func pushing(_ element: Element) -> Self
    func appending(_ other: Self) -> Self
}

protocol ActorPeer: Actor {
    func peer() -> Self
}

class Node {
    init() {}
    func copy() -> Self { self }
    func compare(to other: Node) -> Bool { other === self }
}
