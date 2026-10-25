protocol HasMembers: Token {
    var members: [any Token] { get set }

    func replacing(members: [any Token]) -> Self
}
