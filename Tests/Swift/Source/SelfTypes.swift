protocol Shape {
    var name: String { get }
    func scaled(by factor: Int) -> Self
    func overlaps(_ other: Self) -> Bool
    func union(with others: [Self]) -> Self?
}

class Polygon {
    init() {}

    func duplicate() -> Self {
        self
    }
}
