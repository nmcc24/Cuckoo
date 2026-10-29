import Foundation

protocol Delegate: AnyObject {
    func didFinish(result: Int)
    var name: String { get set }
}

protocol WeakObserver where Self: AnyObject {
    func notify()
}

class BaseView {
    init() {}
    func render() -> String { "base" }
}

protocol ViewModel: BaseView {
    func refresh() -> Int
}

protocol Screen where Self: BaseView {
    func title() -> String
}

protocol DetailScreen: Screen {
    func detail() -> String
}

@MainActor
class MainActorView {
    init() {}
    func layout() {}
}

protocol MainActorViewModel: MainActorView {
    func reload() async -> Int
}

protocol ObjectObserver: NSObjectProtocol {
    func observe(_ value: Int)
}
