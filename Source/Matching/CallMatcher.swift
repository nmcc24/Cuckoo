/// Decides whether the calls that matched in a `verify` are the expected ones, usually by counting them.
///
/// ``times(_:)``, ``never()``, ``atLeast(_:)`` and ``atMost(_:)`` return one; combine them with ``or(_:)`` and
/// ``and(_:)``.
public struct CallMatcher {
    /// How a failure describes the expected calls, such as `2 times`.
    public let name: String
    
    private let matchesFunction: ([any StubCall]) -> Bool
    
    /// Creates a matcher that accepts the matching calls `matchesFunction` returns `true` for.
    public init(name: String, matchesFunction: @escaping ([any StubCall]) -> Bool) {
        self.name = name
        self.matchesFunction = matchesFunction
    }
    
    /// Creates a matcher that compares the expected number of calls with the actual number, using
    /// `compareCallsFunction(expected, actual)`.
    public init(name: String, numberOfExpectedCalls: Int, compareCallsFunction: @escaping (_ expected: Int, _ actual: Int) -> Bool) {
        self.init(name: name) {
            return compareCallsFunction(numberOfExpectedCalls, $0.count)
        }
    }

    /// Whether `calls`, the calls that matched the verified member and arguments, are the expected ones.
    public func matches(_ calls: [any StubCall]) -> Bool {
        return matchesFunction(calls)
    }
    
    /// Returns a matcher that accepts the calls either this matcher or `otherMatcher` accepts.
    public func or(_ otherMatcher: CallMatcher) -> CallMatcher {
        let name = "either \(self.name) or \(otherMatcher.name)"
        return CallMatcher(name: name) {
            return self.matches($0) || otherMatcher.matches($0)
        }
    }
    
    /// Returns a matcher that accepts the calls only when this matcher and `otherMatcher` both accept them.
    public func and(_ otherMatcher: CallMatcher) -> CallMatcher {
        let name = "both \(self.name) and \(otherMatcher.name)"
        return CallMatcher(name: name) {
            return self.matches($0) && otherMatcher.matches($0)
        }
    }
}
