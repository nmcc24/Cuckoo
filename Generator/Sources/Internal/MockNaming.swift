/// How a mock's name is built from the mocked type's: `Mock` + `Service` by default.
struct MockNaming: Hashable, Sendable {
    static let `default` = MockNaming(prefix: "Mock", suffix: "")

    /// The naming the mocks being generated use.
    @TaskLocal static var current = MockNaming.default

    let prefix: String
    let suffix: String

    func mockName(of name: String) -> String {
        prefix + name + suffix
    }
}
