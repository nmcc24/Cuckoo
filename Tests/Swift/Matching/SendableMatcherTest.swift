import Testing
import Cuckoo
@testable import CuckooMocks
@testable import CuckooTestSources

/// Which kind of matcher each matcher function returns, and that a `Sendable` mock's stubs match from any task.
struct SendableMatcherTests {
    /// Not `Sendable`, so its matchers are `ParameterMatcher`s.
    final class Box: Equatable {
        var value: Int

        init(_ value: Int) {
            self.value = value
        }

        static func == (lhs: Box, rhs: Box) -> Bool {
            lhs.value == rhs.value
        }
    }

    @Test
    func sendableValuesGiveSendableMatchers() {
        let int: SendableMatcher<Int> = equal(to: 3)
        let optional: SendableMatcher<Int?> = equal(to: 3)
        let array: SendableMatcher<[Int]> = equal(to: [1, 2])
        let set: SendableMatcher<Set<Int>> = equal(to: Set([1]))
        let dictionary: SendableMatcher<[String: Int]> = equal(to: ["a": 1])
        let contains: SendableMatcher<[Int]> = containsAnyOf(values: 1, 2)
        let keys: SendableMatcher<[String: Int]> = containsAllKeysOf(values: "a")

        #expect(int.matches(3) && !int.matches(4))
        #expect(optional.matches(3) && !optional.matches(nil))
        #expect(array.matches([1, 2]) && !array.matches([2, 1]))
        #expect(set.matches([1]))
        #expect(dictionary.matches(["a": 1]))
        #expect(contains.matches([2, 5]) && !contains.matches([5]))
        #expect(keys.matches(["a": 0]) && !keys.matches(["b": 0]))
    }

    @Test
    func nonSendableValuesGiveParameterMatchers() {
        let box = Box(1)
        let matcher: ParameterMatcher<Box> = equal(to: box)
        let contains: ParameterMatcher<[Box]> = containsAnyOf(values: box)

        #expect(matcher.matches(Box(1)) && !matcher.matches(Box(2)))
        #expect(contains.matches([Box(1)]))
    }

    @Test
    func aClosureThatCapturesNonSendableStateGivesAParameterMatcher() {
        let box = Box(1)
        let matcher = equal(to: 2, equalWhen: { $0 == $1 + box.value })

        #expect(matcher.matches(1))
        #expect(type(of: matcher) == ParameterMatcher<Int>.self)
    }

    @Test
    func identityMatchersAreSendableForAnyClass() {
        let box = Box(1)
        let matcher: SendableMatcher<Box> = sameInstance(as: box)

        #expect(matcher.matches(box) && !matcher.matches(Box(1)))
    }

    @Test
    func combinatorsKeepTheKind() {
        let or: SendableMatcher<Int> = equal(to: 1).or(equal(to: 2))
        let and: SendableMatcher<Int> = equal(to: 1).and(any())
        let negated: SendableMatcher<Int> = not(equal(to: 1))
        let mixed: ParameterMatcher<Int> = equal(to: 1).or(ParameterMatcher { $0 > 5 })

        #expect(or.matches(2) && !or.matches(3))
        #expect(and.matches(1))
        #expect(negated.matches(2) && !negated.matches(1))
        #expect(mixed.matches(6) && !mixed.matches(2))
    }

    @Test
    func aCaptorOfSendableValuesIsSendable() {
        let captor = ArgumentCaptor<Int>()
        let matcher: SendableMatcher<Int> = captor.capture()

        #expect(matcher.matches(4))
        #expect(captor.value == 4)
    }

    @Test
    func aSendableMocksStubsMatchFromAnyTask() async {
        let mock = MockConcurrentCounter()
        stub(mock) { stub in
            when(stub.count(characters: any())).thenReturn(0)
            when(stub.count(characters: equal(to: "a").or("b"))).thenReturn(1)
            when(stub.count(characters: hasLength(atLeast: 3))).thenReturn(3)
        }

        let total = await withTaskGroup(of: Int.self) { group in
            for characters in ["a", "b", "abc", "zz"] {
                group.addTask {
                    mock.count(characters: characters)
                }
            }
            return await group.reduce(0, +)
        }

        #expect(total == 1 + 1 + 3 + 0)
    }
}
