import Testing
import Cuckoo

struct ParameterMatcherTest {
    @Test
    func matches() {
        let matcher = ParameterMatcher { $0 == 5 }
        
        #expect(matcher.matches(5))
        #expect(!matcher.matches(4))
    }
    
    @Test
    func or() {
        let matcher = ParameterMatcher { $0 == 5 }.or(ParameterMatcher { $0 == 4 })
        
        #expect(matcher.matches(5))
        #expect(matcher.matches(4))
        #expect(!matcher.matches(3))
    }
    
    @Test
    func and() {
        let matcher = ParameterMatcher { $0 > 3 }.and(ParameterMatcher { $0 < 5 })
        
        #expect(matcher.matches(4))
        #expect(!matcher.matches(3))
    }

    @Test
    func testNot() {
        let matcher = not(ParameterMatcher { $0 > 3 })

        #expect(matcher.matches(3))
        #expect(matcher.matches(2))
        #expect(matcher.matches(-1))
        #expect(!matcher.matches(4))
        #expect(!matcher.matches(10))
    }
}
