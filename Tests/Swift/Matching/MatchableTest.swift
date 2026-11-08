import Testing
import Cuckoo

struct MatchableTest {
    @Test
    func or() {
        let matcher = 5.or(4)
        
        #expect(matcher.matches(5))
        #expect(matcher.matches(4))
        #expect(!matcher.matches(3))
    }

    @Test
    func and() {
        let matcher = 5.and(ParameterMatcher { $0 > 4 })
        
        #expect(matcher.matches(5))
        #expect(!matcher.matches(4))
    }

    @Test
    func bool() {
        #expect(true.matcher.matches(true))
        #expect(!true.matcher.matches(false))
    }

    @Test
    func int() {
        #expect(1.matcher.matches(1))
        #expect(!1.matcher.matches(2))
    }

    @Test
    func string() {
        #expect("a".matcher.matches("a"))
        #expect(!"a".matcher.matches("b"))
    }

    @Test
    func float() {
        #expect(Float(1.1).matcher.matches(1.1))
        #expect(!Float(1.1).matcher.matches(1.2))
    }

    @Test
    func double() {
        #expect(1.1.matcher.matches(1.1))
        #expect(!1.1.matcher.matches(1.2))
    }

    @Test
    func character() {
        #expect(Character("a").matcher.matches("a"))
        #expect(!Character("a").matcher.matches("b"))
    }
}
