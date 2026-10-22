@MainActor
class ViewModel {
    var state: String = ""
    init() {}
    func reload() async {}
    func select(index: Int) -> Bool { true }
}
