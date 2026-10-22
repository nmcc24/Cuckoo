class NonSendableBox { var v = 0 }
protocol Transfer {
    func take(_ box: sending NonSendableBox)
    func make() -> sending NonSendableBox
}
