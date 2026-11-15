// Value generics, `let N: Int`, on a class and on a method, which the mock keeps as declared.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, *)
class FixedBuffer<let Count: Int> {
    init() {}
    func first<let N: Int>(_ values: InlineArray<N, Int>) -> Int { 0 }
}
