struct Token: ~Copyable { var id: Int }
protocol Consumer {
    func consume(_ token: consuming Token)
    func inspect(_ token: borrowing Token) -> Int
}
