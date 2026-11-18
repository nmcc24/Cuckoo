import Cuckoo

// Settable properties and subscripts of a function type in a protocol with an associated type, whose type eraser
// stores a closure for each setter: the new value escapes into it however its type is spelled, as a typealias, the
// protocol's own typealias or an implicitly unwrapped optional, which a function type can't name with its `!`.
typealias Handler = (Int) -> Void

protocol Observed {
    associatedtype Value
    typealias Callback = (Value) -> Void

    var handler: Handler { get set }
    var optionalHandler: Handler? { get set }
    var sendableHandler: @Sendable (Int) -> Void { get set }
    var callback: Callback { get set }
    var implicit: ((Value) -> Void)! { get set }
    var implicitHandler: Handler! { get set }
    var implicitValue: Value! { get set }
    var readOnlyImplicit: Value! { get }
    subscript(index: Int) -> Handler { get set }
    subscript(implicit index: Int) -> Value! { get set }
    func value() -> Value
}

struct Observer: Observed {
    var handler: Handler = { _ in }
    var optionalHandler: Handler?
    var sendableHandler: @Sendable (Int) -> Void = { _ in }
    var callback: (String) -> Void = { _ in }
    var implicit: ((String) -> Void)!
    var implicitHandler: Handler!
    var implicitValue: String!
    var readOnlyImplicit: String! { nil }
    subscript(index: Int) -> Handler {
        get { handler }
        set { handler = newValue }
    }
    subscript(implicit index: Int) -> String! {
        get { implicitValue }
        set { implicitValue = newValue }
    }
    func value() -> String { "" }
}

func useFunctionValues() {
    let mock = MockObserved<String>()
    mock.enableDefaultImplementation(Observer())
    mock.handler = { _ in }
    mock.callback = { _ in }
    mock.implicit = nil
    mock[0] = { _ in }
    mock[implicit: 0] = "value"
}
