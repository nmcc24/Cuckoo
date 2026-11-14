infix operator <~>: AdditionPrecedence

/// Operator requirements, which the mock implements as static members its proxies name with words.
protocol Amount {
    static func + (lhs: Self, rhs: Self) -> Self
    static prefix func - (value: Self) -> Self
    static postfix func ++ (value: inout Self)
    static func <~> (lhs: Self, rhs: Int) -> Bool
}
