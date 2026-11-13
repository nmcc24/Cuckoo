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
        #expect((sameInstance(as: x) as ParameterMatcher<X?>).matches(x))
        #expect(!(sameInstance(as: x) as ParameterMatcher<X?>).matches(nil))
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
    func testAnyInt() {
        #expect(anyInt().matches(1))
    }

    @Test
    func testAnyString() {
        #expect(anyString().matches("a"))
    }

    @Test
    func testAny() {
        #expect(any().matches(X()))
    }

    @Test
    func testIsNil() {
        let optional: X? = nil
        #expect(isNil().matches(nil as X?))
        #expect(isNil().matches(optional))
        #expect(!isNil().matches(X()))
    }

    @Test
    func testAnyClosure() {
        #expect((anyClosure() as ParameterMatcher<() -> Int>).matches { 0 })
        #expect((anyClosure() as ParameterMatcher<(Int) -> Int>).matches { _ in 0 })
        #expect((anyClosure() as ParameterMatcher<(Int, Int) -> Int>).matches { _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<(Int, Int, Int) -> Int>).matches { _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<(Int, Int, Int, Int) -> Int>).matches { _, _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<(Int, Int, Int, Int, Int) -> Int>).matches { _, _, _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<(Int, Int, Int, Int, Int, Int) -> Int>).matches { _, _, _, _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<(Int, Int, Int, Int, Int, Int, Int) -> Int>).matches { _, _, _, _, _, _, _ in 0 })
    }

    @Test
    func anySendableClosure() {
        #expect((anyClosure() as ParameterMatcher<@Sendable () -> Int>).matches { 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int) -> Int>).matches { _ in 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int, Int) -> Int>).matches { _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int, Int, Int) -> Int>).matches { _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int) -> Int>).matches { _, _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int) -> Int>).matches { _, _, _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int, Int) -> Int>).matches { _, _, _, _, _, _ in 0 })
        #expect((anyClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int, Int, Int) -> Int>).matches { _, _, _, _, _, _, _ in 0 })
    }

    @Test
    func anyOptionalSendableClosureRejectsNil() {
        #expect(!(anyClosure() as ParameterMatcher<(@Sendable () -> Int)?>).matches(nil))
        #expect((anyClosure() as ParameterMatcher<(@Sendable () -> Int)?>).matches { 0 })
        #expect(!(anyClosure() as ParameterMatcher<(@Sendable () async -> Int)?>).matches(nil))
        #expect((anyClosure() as ParameterMatcher<(@Sendable () async -> Int)?>).matches { 0 })
        #expect(!(anyClosure() as ParameterMatcher<(@Sendable (Int) -> Int)?>).matches(nil))
    }

    @Test
    func testAnyThrowingClosure() {
        struct MockError: Error { }
        
        #expect((anyThrowingClosure() as ParameterMatcher<() throws -> Int>).matches { 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int) throws -> Int>).matches { _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int) throws -> Int>).matches { _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int) throws -> Int>).matches { _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _, _ in 0 })

        #expect((anyThrowingClosure() as ParameterMatcher<() throws -> Int>).matches { throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int) throws -> Int>).matches { _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int) throws -> Int>).matches { _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int) throws -> Int>).matches { _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<(Int, Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _, _ in throw MockError() })
    }

    @Test
    func anySendableThrowingClosure() {
        struct MockError: Error { }

        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable () throws -> Int>).matches { 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int) throws -> Int>).matches { _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int) throws -> Int>).matches { _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int) throws -> Int>).matches { _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _ in 0 })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _ in 0 })

        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable () throws -> Int>).matches { throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int) throws -> Int>).matches { _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int) throws -> Int>).matches { _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int) throws -> Int>).matches { _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _ in throw MockError() })
        #expect((anyThrowingClosure() as ParameterMatcher<@Sendable (Int, Int, Int, Int, Int, Int, Int) throws -> Int>).matches { _, _, _, _, _, _, _ in throw MockError() })
    }

    @Test
    func testAnyOptionalThrowingClosure() {
        #expect(anyOptionalThrowingClosure().matches { (i: String) in 0 })
        #expect(anyOptionalThrowingClosure().matches { (p: Int) throws in 1 })
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
    func optionalAnyInt() {
        #expect(anyInt().matches(1 as Int?))
        #expect(!anyString().matches(nil as String?))
    }

    @Test
    func optionalAnyString() {
        #expect(anyString().matches("a" as String?))
        #expect(!anyString().matches(nil as String?))
    }

    @Test
    func optionalAny() {
        #expect(any(X.self).matches(X() as X?))
        #expect(any(X.self).matches(nil as X?))
    }

    @Test
    func optionalAnyClosure() {
        #expect(anyClosure().matches({ (arg) in let () = arg; return 0 } as ((()) -> Int)?))
        #expect(!anyClosure().matches(nil as ((()) -> Int)?))
    }

    @Test
    func testNotNil() {
        #expect(notNil().matches(X()))
        #expect(!notNil().matches(nil as X?))
    }

    private class X {
    }
}
