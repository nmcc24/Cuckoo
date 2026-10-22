import Foundation

struct OrderedSet<Element: Hashable>: ExpressibleByArrayLiteral {
    private(set) var values: [Element] = []
    private var members: Set<Element> = []

    init() {}

    init(arrayLiteral elements: Element...) {
        self.init(elements)
    }

    init(_ array: [Element]) {
        for element in array {
            insert(element)
        }
    }

    func contains(_ member: Element) -> Bool {
        members.contains(member)
    }

    mutating func insert(_ newMember: Element) {
        guard members.insert(newMember).inserted else { return }
        values.append(newMember)
    }

    mutating func remove(_ member: Element) {
        guard members.remove(member) != nil else { return }
        values.removeAll { $0 == member }
    }

    func union(_ other: OrderedSet<Element>) -> OrderedSet<Element> {
        OrderedSet(values + other.values)
    }

    func intersection(_ other: OrderedSet<Element>) -> OrderedSet<Element> {
        OrderedSet(values.filter(other.contains))
    }
}
