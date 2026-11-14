import Cuckoo

prefix operator √
infix operator <~>: AdditionPrecedence

protocol Vector {
    static func + (lhs: Self, rhs: Self) -> Self
    static prefix func - (value: Self) -> Self
    static postfix func ++ (value: inout Self)
    static prefix func ++ (value: inout Self)
    static func += (lhs: inout Self, rhs: Self)
    static func <~> (lhs: Self, rhs: Int) -> Bool
    static prefix func √ (value: Self) -> Double
    static func == (lhs: Self, rhs: Self) -> Bool
}

@MainActor
protocol Score {
    static func < (lhs: Self, rhs: Self) -> Bool
}

// A class's own operators are final, so its mock keeps them.
class Money {
    init() {}

    static func + (lhs: Money, rhs: Money) -> Money { lhs }
    func amount() -> Int { 0 }
}

func useVectors() {
    withStaticStubs {
        let sum = MockVector()
        stub(MockVector.self) { stub in
            when(stub.operatorPlus(any(), any())).thenReturn(sum)
            when(stub.prefixOperatorMinus(any())).thenReturn(sum)
            when(stub.postfixOperatorPlusPlus(any())).thenDoNothing()
            when(stub.prefixOperatorPlusPlus(any())).thenDoNothing()
            when(stub.operatorPlusEqual(any(), any())).thenDoNothing()
            when(stub.operatorLessTildeGreater(any(), 3)).thenReturn(true)
            when(stub.prefixOperatorU221A(any())).thenReturn(2)
            when(stub.operatorEqualEqual(any(), any())).thenReturn(false)
        }
        var vector = MockVector()
        _ = vector + vector
        _ = -vector
        vector++
        ++vector
        vector += sum
        _ = vector <~> 3
        _ = √vector
        _ = vector == sum
        verify(MockVector.self).operatorPlus(any(), any())
        verify(MockVector.self).postfixOperatorPlusPlus(any())
        verify(MockVector.self).prefixOperatorPlusPlus(any())
        verify(MockVector.self).prefixOperatorU221A(any())
    }
}

@MainActor
func useScores() {
    withStaticStubs {
        stub(MockScore.self) { stub in
            when(stub.operatorLess(any(), any())).thenReturn(true)
        }
        _ = MockScore() < MockScore()
        verify(MockScore.self).operatorLess(any(), any())
    }
}

func useMoney() {
    let money = MockMoney()
    _ = money + money
}
