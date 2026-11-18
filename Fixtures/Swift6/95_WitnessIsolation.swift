// A `nonisolated` class, stated or through its superclass, that conforms to protocols with a global actor. With
// `-default-isolation MainActor` Swift gives each member that implements a requirement the requirement's actor: the
// protocol's, which may be the default, or the requirement's own. The mock's overrides state it. The class's other
// members, and the ones implementing a `nonisolated` requirement, stay nonisolated.
@globalActor
actor Background {
    static let shared = Background()
}

nonisolated class Plain {
    init() {}
}

protocol Showing {
    var title: String { get set }
    func show()
    func load() async -> Int
    nonisolated func describe() -> String
    subscript(index: Int) -> Int { get }
}

protocol Presenting: Showing {
    func present()
}

@Background
protocol Syncing {
    func sync()
}

nonisolated protocol Mixed {
    @MainActor func onMain()
    func anywhere()
}

class Screen: Plain, Presenting, Syncing, Mixed {
    var title = ""
    func show() {}
    func load() async -> Int { 0 }
    func describe() -> String { "" }
    subscript(index: Int) -> Int { index }
    func present() {}
    func sync() {}
    func onMain() {}
    func anywhere() {}
    func own() {}
    // A member that states its isolation keeps it.
    nonisolated func stated() {}
}

nonisolated class Panel: Showing {
    init() {}
    var title = ""
    func show() {}
    func load() async -> Int { 0 }
    func describe() -> String { "" }
    subscript(index: Int) -> Int { index }
    func own() {}
}

// Nonisolated in every mode.
nonisolated func callNonisolated(_ screen: MockScreen, _ panel: MockPanel) -> String {
    screen.own()
    screen.anywhere()
    screen.stated()
    panel.own()
    return screen.describe() + panel.describe()
}

@MainActor
func callOnMain(_ screen: MockScreen, _ panel: MockPanel) -> Int {
    screen.show()
    screen.present()
    screen.onMain()
    screen.title = panel.title
    return screen[0] + panel[0]
}
