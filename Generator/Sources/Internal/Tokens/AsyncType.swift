enum AsyncType: String, CustomStringConvertible, Equatable {
    case `async`

    var isAsync: Bool {
        self == .async
    }

    var description: String {
        rawValue
    }
}
