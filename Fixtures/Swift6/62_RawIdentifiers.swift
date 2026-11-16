// Raw identifiers (SE-0451) in a protocol with an associated type, whose eraser stores a closure per member.
protocol Spelled {
    associatedtype Item
    func `load all`() -> [Item]
    var `item count`: Int { get }
    func `default`() -> Item
}
