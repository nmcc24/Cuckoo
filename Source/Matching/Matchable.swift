/// A value that can stand for an argument in stubbing and verification, by producing its own matcher.
///
/// Literals and common standard types conform, so `when(stub.greet("Ann"))` matches the argument `"Ann"`.
/// Every `Equatable` type that adopts `Matchable` gets an `equal(to:)` matcher for free.
public protocol Matchable {
    /// The type of the arguments this value matches.
    associatedtype MatchedType

    /// The matcher this value stands for, usually `equal(to:)` of the value itself.
    var matcher: ParameterMatcher<MatchedType> { get }
}

/// A value that can stand for an optional argument, so `"Ann"` matches a `String?` parameter too.
public protocol OptionalMatchable {
    /// The wrapped type of the optional arguments this value matches.
    associatedtype OptionalMatchedType

    /// The matcher for an optional argument: it matches when the argument holds an equal value.
    var optionalMatcher: ParameterMatcher<OptionalMatchedType?> { get }
}

public extension Matchable {
    /// Returns a matcher that accepts an argument either this value or `otherMatchable` accepts.
    func or<M>(_ otherMatchable: M) -> ParameterMatcher<MatchedType> where M: Matchable, M.MatchedType == MatchedType {
        return ParameterMatcher {
            return self.matcher.matches($0) || otherMatchable.matcher.matches($0)
        }
    }
    
    /// Returns a matcher that accepts an argument only when this value and `otherMatchable` both accept it.
    func and<M>(_ otherMatchable: M) -> ParameterMatcher<MatchedType> where M: Matchable, M.MatchedType == MatchedType {
        return ParameterMatcher {
            return self.matcher.matches($0) && otherMatchable.matcher.matches($0)
        }
    }
}

extension Optional: Matchable where Wrapped: Matchable, Wrapped.MatchedType == Wrapped {
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

extension Optional: OptionalMatchable where Wrapped: OptionalMatchable, Wrapped.OptionalMatchedType == Wrapped {
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

extension Matchable where Self: Equatable {
    /// Matches an argument equal to this value.
    public var matcher: ParameterMatcher<Self> {
        return equal(to: self)
    }
}

extension OptionalMatchable where OptionalMatchedType == Self, Self: Equatable {
    /// Matches an optional argument that holds a value equal to this one.
    public var optionalMatcher: ParameterMatcher<OptionalMatchedType?> {
        return ParameterMatcher { other in
            return Optional(self) == other
        }
    }
}

extension Bool: Matchable {}
extension Bool: OptionalMatchable {
    public typealias OptionalMatchedType = Bool
}

extension String: Matchable {}
extension String: OptionalMatchable {
    public typealias OptionalMatchedType = String
}

extension Float: Matchable {}
extension Float: OptionalMatchable {
    public typealias OptionalMatchedType = Float
}

extension Double: Matchable {}
extension Double: OptionalMatchable {
    public typealias OptionalMatchedType = Double
}

extension Character: Matchable {}
extension Character: OptionalMatchable {
    public typealias OptionalMatchedType = Character
}

extension Int: Matchable {}
extension Int: OptionalMatchable {
    public typealias OptionalMatchedType = Int
}

extension Int8: Matchable {}
extension Int8: OptionalMatchable {
    public typealias OptionalMatchedType = Int8
}

extension Int16: Matchable {}
extension Int16: OptionalMatchable {
    public typealias OptionalMatchedType = Int16
}

extension Int32: Matchable {}
extension Int32: OptionalMatchable {
    public typealias OptionalMatchedType = Int32
}

extension Int64: Matchable {}
extension Int64: OptionalMatchable {
    public typealias OptionalMatchedType = Int64
}

extension UInt: Matchable {}
extension UInt: OptionalMatchable {
    public typealias OptionalMatchedType = UInt
}

extension UInt8: Matchable {}
extension UInt8: OptionalMatchable {
    public typealias OptionalMatchedType = UInt8
}

extension UInt16: Matchable {}
extension UInt16: OptionalMatchable {
    public typealias OptionalMatchedType = UInt16
}

extension UInt32: Matchable {}
extension UInt32: OptionalMatchable {
    public typealias OptionalMatchedType = UInt32
}

extension UInt64: Matchable {}
extension UInt64: OptionalMatchable {
    public typealias OptionalMatchedType = UInt64
}
