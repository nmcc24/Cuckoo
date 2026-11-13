/// A value that can stand for an argument in stubbing and verification, by producing its own matcher.
///
/// Literals and common standard types conform, so `when(stub.greet("Ann"))` matches the argument `"Ann"`.
/// Every `Equatable` type that adopts `_Matchable` gets an `equal(to:)` matcher for free.
public protocol _Matchable {
    /// The type of the arguments this value matches.
    associatedtype MatchedType

    /// The matcher this value stands for, usually `equal(to:)` of the value itself.
    var matcher: ParameterMatcher<MatchedType> { get }
}

/// A value that can stand for an optional argument, so `"Ann"` matches a `String?` parameter too.
public protocol _OptionalMatchable {
    /// The wrapped type of the optional arguments this value matches.
    associatedtype OptionalMatchedType

    /// The matcher for an optional argument: it matches when the argument holds an equal value.
    var optionalMatcher: ParameterMatcher<OptionalMatchedType?> { get }
}

public extension _Matchable {
    /// Returns a matcher that accepts an argument either this value or `otherMatchable` accepts.
    func or<M>(_ otherMatchable: M) -> ParameterMatcher<MatchedType> where M: _Matchable, M.MatchedType == MatchedType {
        return ParameterMatcher {
            return self.matcher.matches($0) || otherMatchable.matcher.matches($0)
        }
    }
    
    /// Returns a matcher that accepts an argument only when this value and `otherMatchable` both accept it.
    func and<M>(_ otherMatchable: M) -> ParameterMatcher<MatchedType> where M: _Matchable, M.MatchedType == MatchedType {
        return ParameterMatcher {
            return self.matcher.matches($0) && otherMatchable.matcher.matches($0)
        }
    }
}

public extension _SendableMatchable {
    /// Returns a matcher that accepts an argument either this value or `otherMatchable` accepts.
    func or<M>(_ otherMatchable: M) -> SendableMatcher<MatchedType> where M: _SendableMatchable, M.MatchedType == MatchedType {
        let matcher = sendableMatcher
        let otherMatcher = otherMatchable.sendableMatcher
        return SendableMatcher {
            matcher.matches($0) || otherMatcher.matches($0)
        }
    }

    /// Returns a matcher that accepts an argument only when this value and `otherMatchable` both accept it.
    func and<M>(_ otherMatchable: M) -> SendableMatcher<MatchedType> where M: _SendableMatchable, M.MatchedType == MatchedType {
        let matcher = sendableMatcher
        let otherMatcher = otherMatchable.sendableMatcher
        return SendableMatcher {
            matcher.matches($0) && otherMatcher.matches($0)
        }
    }
}

extension Optional: _Matchable where Wrapped: _Matchable, Wrapped.MatchedType == Wrapped {
    /// An optional matches optional arguments.
    public typealias MatchedType = Wrapped?

    /// Matches `nil` against `nil`, and a wrapped value with the wrapped value's matcher.
    public var matcher: ParameterMatcher<Wrapped?> {
        return ParameterMatcher<Wrapped?> { other in
            switch (self, other) {
            case (.none, .none):
                return true
            case (.some(let lhs), .some(let rhs)):
                return lhs.matcher.matches(rhs)
            default:
                return false
            }
        }
    }
}

extension Optional: _SendableMatchable where Wrapped: _SendableMatchable, Wrapped.MatchedType == Wrapped {
    /// Matches `nil` against `nil`, and a wrapped value with the wrapped value's matcher.
    public var sendableMatcher: SendableMatcher<Wrapped?> {
        let wrappedMatcher = self?.sendableMatcher
        return SendableMatcher<Wrapped?> { other in
            switch (wrappedMatcher, other) {
            case (.none, .none):
                return true
            case (.some(let lhs), .some(let rhs)):
                return lhs.matches(rhs)
            default:
                return false
            }
        }
    }
}

extension Optional: _OptionalMatchable where Wrapped: _OptionalMatchable, Wrapped.OptionalMatchedType == Wrapped {
    /// An optional matches optional arguments of its wrapped type.
    public typealias OptionalMatchedType = Wrapped

    /// Matches `nil` against `nil`, and a wrapped value with the wrapped value's optional matcher.
    public var optionalMatcher: ParameterMatcher<Wrapped?> {
        return ParameterMatcher<Wrapped?> { other in
            switch (self, other) {
            case (.none, .none):
                return true
            case (.some(let lhs), .some(let rhs)):
                return lhs.optionalMatcher.matches(rhs)
            default:
                return false
            }
        }
    }
}

extension Optional: _SendableOptionalMatchable where Wrapped: _SendableOptionalMatchable, Wrapped.OptionalMatchedType == Wrapped {
    /// Matches `nil` against `nil`, and a wrapped value with the wrapped value's optional matcher.
    public var sendableOptionalMatcher: SendableMatcher<Wrapped?> {
        let wrappedMatcher = self?.sendableOptionalMatcher
        return SendableMatcher<Wrapped?> { other in
            switch (wrappedMatcher, other) {
            case (.none, .none):
                return true
            case (.some(let lhs), .some(let rhs)):
                return lhs.matches(rhs)
            default:
                return false
            }
        }
    }
}

extension _Matchable where Self: Equatable {
    /// Matches an argument equal to this value.
    public var matcher: ParameterMatcher<Self> {
        return equal(to: self)
    }
}

extension _OptionalMatchable where OptionalMatchedType == Self, Self: Equatable {
    /// Matches an optional argument that holds a value equal to this one.
    public var optionalMatcher: ParameterMatcher<OptionalMatchedType?> {
        return ParameterMatcher { other in
            return Optional(self) == other
        }
    }
}

extension _SendableMatchable where Self: Equatable {
    /// Matches an argument equal to this value.
    public var sendableMatcher: SendableMatcher<Self> {
        equal(to: self)
    }

    /// Matches an argument equal to this value.
    public var matcher: ParameterMatcher<Self> {
        sendableMatcher.matcher
    }
}

extension _SendableOptionalMatchable where OptionalMatchedType == Self, Self: Equatable {
    /// Matches an optional argument that holds a value equal to this one.
    public var sendableOptionalMatcher: SendableMatcher<OptionalMatchedType?> {
        SendableMatcher { other in
            Optional(self) == other
        }
    }

    /// Matches an optional argument that holds a value equal to this one.
    public var optionalMatcher: ParameterMatcher<OptionalMatchedType?> {
        sendableOptionalMatcher.matcher
    }
}

extension Bool: _SendableMatchable {}
extension Bool: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Bool
}

extension String: _SendableMatchable {}
extension String: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = String
}

extension Float: _SendableMatchable {}
extension Float: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Float
}

extension Double: _SendableMatchable {}
extension Double: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Double
}

extension Character: _SendableMatchable {}
extension Character: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Character
}

extension Int: _SendableMatchable {}
extension Int: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Int
}

extension Int8: _SendableMatchable {}
extension Int8: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Int8
}

extension Int16: _SendableMatchable {}
extension Int16: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Int16
}

extension Int32: _SendableMatchable {}
extension Int32: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Int32
}

extension Int64: _SendableMatchable {}
extension Int64: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = Int64
}

extension UInt: _SendableMatchable {}
extension UInt: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = UInt
}

extension UInt8: _SendableMatchable {}
extension UInt8: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = UInt8
}

extension UInt16: _SendableMatchable {}
extension UInt16: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = UInt16
}

extension UInt32: _SendableMatchable {}
extension UInt32: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = UInt32
}

extension UInt64: _SendableMatchable {}
extension UInt64: _SendableOptionalMatchable {
    public typealias OptionalMatchedType = UInt64
}
