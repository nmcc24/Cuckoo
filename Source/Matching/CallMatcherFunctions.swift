/// Returns a matcher expecting exactly `count` matching calls.
public func times(_ count: Int) -> CallMatcher {
    let name = count == 0 ? "never" : "\(count) times"
    return CallMatcher(name: name, numberOfExpectedCalls: count, compareCallsFunction: ==)
}

/// Returns a matcher expecting no matching call.
public func never() -> CallMatcher {
    return times(0)
}

/// Returns a matcher expecting one matching call or more.
public func atLeastOnce() -> CallMatcher {
    return atLeast(1)
}

/// Returns a matcher expecting `count` matching calls or more.
public func atLeast(_ count: Int) -> CallMatcher {
    return CallMatcher(name: "at least \(count) times", numberOfExpectedCalls: count, compareCallsFunction: <=)
}

/// Returns a matcher expecting `count` matching calls or fewer.
public func atMost(_ count: Int) -> CallMatcher {
    return CallMatcher(name: "at most \(count) times",numberOfExpectedCalls: count, compareCallsFunction: >=)
}
