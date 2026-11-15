import Testing
import Cuckoo

struct ParameterMatcherFunctionsTest {
    @Test
    func equalToEquatable() {
        #expect(equal(to: 1).matches(1))
        #expect(!equal(to: 1).matches(2))
    }

    @Test
    func sameInstanceComparesIdentity() {
        let x = X()

        #expect(sameInstance(as: x).matches(x))
        #expect(!sameInstance(as: x).matches(X()))
        #expect((sameInstance(as: x) as SendableMatcher<X?>).matches(x))
        #expect(!(sameInstance(as: x) as SendableMatcher<X?>).matches(nil))
    }

    /// An `Equatable` class used to make `equal(to:)` ambiguous between the `Equatable` and the identity overloads.
    @Test
    func equalToAnEquatableClassUsesEquality() {
        final class Point: Equatable {
            let x: Int
            init(x: Int) { self.x = x }
            static func == (lhs: Point, rhs: Point) -> Bool { lhs.x == rhs.x }
        }

        #expect(equal(to: Point(x: 1)).matches(Point(x: 1)))
        #expect(!equal(to: Point(x: 1)).matches(Point(x: 2)))
        let optional: Point? = Point(x: 1)
        #expect(equal(to: optional).matches(Point(x: 1)))
    }

    @Test
    func equalToWithFunction() {
        let tuple = (1, 1)
        let function = { (a: (Int, Int), b: (Int, Int)) -> Bool in
            return a.0 == b.0 && a.1 == b.1
        }

        #expect(equal(to: tuple, equalWhen: function).matches((1, 1)))
        #expect(!equal(to: tuple, equalWhen: function).matches((1, 2)))
    }

    @Test
    func equalToArray() {
        #expect(equal(to: [1, 2, 3]).matches([1, 2, 3]))
        #expect(!equal(to: [1, 2, 3]).matches([1, 3, 2]))
    }

    @Test
    func equalToSet() {
        #expect(equal(to: [1, 2, 3] as Set<Int>).matches([1, 2, 3] as Set<Int>))
        #expect(equal(to: [1, 2, 3] as Set<Int>).matches([1, 3, 2] as Set<Int>))
        #expect(!equal(to: [1, 2, 3] as Set<Int>).matches([1, 2] as Set<Int>))
    }

    @Test
    func equalToDictionary() {
        #expect(equal(to: ["one": 1, "two": 2, "three": 3] as [String: Int]).matches(["one": 1, "two": 2, "three": 3] as [String: Int]))
        #expect(equal(to: ["one": 1, "two": 2, "three": 3, "four": 4] as [String: Int]).matches(["four": 4, "one": 1, "three": 3, "two": 2] as [String: Int]))
        #expect(!equal(to: ["one": 1, "two": 2, "three": 3] as [String: Int]).matches(["one": 2, "two": 3, "three": 4] as [String: Int]))
    }

    @Test
    func testAny() {
        #expect(any().matches(X()))
    }

    @Test
    func anyMatchesClosures() {
        #expect((any() as SendableMatcher<(Int) -> Int>).matches { $0 })
        #expect((any() as SendableMatcher<@Sendable (Int, Int) throws -> Int>).matches { _, _ in 0 })
        #expect((any() as SendableMatcher<(Int) async throws -> Int>).matches { $0 })
    }

    @Test
    func testIsNil() {
        let optional: X? = nil
        #expect(isNil().matches(nil as X?))
        #expect(isNil().matches(optional))
        #expect(!isNil().matches(X()))
    }

    @Test
    func optionalEqualToEquatable() {
        #expect(equal(to: nil as Int?).matches(nil))
        #expect(equal(to: 1 as Int?).matches(1))
        #expect(!equal(to: 1 as Int?).matches(2))
        #expect(!equal(to: nil).matches(1))
    }

    @Test
    func optionalSameInstance() {
        let x: X? = X()

        #expect(sameInstance(as: nil as X?).matches(nil))
        #expect(sameInstance(as: x).matches(x))
        #expect(!sameInstance(as: x).matches(X()))
        #expect(!sameInstance(as: nil as X?).matches(x))
    }

    @Test
    func optionalEqualToWithFunction() {
        let tuple: (Int, Int)? = (1, 1)
        let function = { (a: (Int, Int)?, b: (Int, Int)?) -> Bool in
            guard let x = a, let y = b else {
                return a == nil && b == nil
            }
            return x.0 == y.0 && x.1 == y.1
        }

        #expect(equal(to: nil, equalWhen: function).matches(nil))
        #expect(equal(to: tuple, equalWhen: function).matches((1, 1)))
        #expect(!equal(to: tuple, equalWhen: function).matches((1, 2)))
        #expect(!equal(to: nil, equalWhen: function).matches(tuple))
    }

    @Test
    func optionalAny() {
        #expect(any(X.self).matches(X() as X?))
        #expect(any(X.self).matches(nil as X?))
    }

    @Test
    func testNotNil() {
        #expect(notNil().matches(X()))
        #expect(!notNil().matches(nil as X?))
    }

    private class X {
    }
}
