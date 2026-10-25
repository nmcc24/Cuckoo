import Foundation

/// The actor isolation a declaration states in source.
enum Isolation: Hashable {
    /// `@MainActor`, or another global actor.
    case globalActor(String)
    /// The `nonisolated` modifier: opts a member out of its type's isolation.
    case nonisolated

    var sourceDescription: String {
        switch self {
        case .globalActor(let name):
            "@\(name)"
        case .nonisolated:
            "nonisolated"
        }
    }
}

/// How a stub's `then` closures and returned values are typed, from the mocked member's isolation.
/// The names match `Cuckoo.StubSharing`.
struct StubIsolation {
    enum Sharing: String {
        case confined = "Confined"
        case shared = "Shared"
        case isolated = "Isolated"
    }

    /// The closure's attributes, e.g. `@MainActor @Sendable `, with a trailing space when not empty.
    let closureAttributes: String
    let sharing: Sharing
    /// For an actor mock's isolated members, the closure's leading `isolated MockX` parameter: the
    /// closure runs on the mock's actor and gets the mock itself.
    let isolatedParameter: String?

    var sharingType: String {
        "Cuckoo.StubSharing.\(sharing.rawValue)"
    }

    /// The `then` closure type for `input` (the parenthesized parameter list) and `output`.
    func implementationType(input: String, output: String, isAsync: Bool, throwsClause: String?) -> String {
        let effects = [isAsync ? "async" : nil, throwsClause].compactMap { $0 }.joined(separator: " ")
        // A nonisolated async closure runs on the caller's actor, like the member it stands in for, so
        // the call's non-`Sendable` arguments don't have to cross into the concurrent pool. An actor
        // mock's closure is isolated by its `isolated` parameter instead.
        let execution = isAsync && sharing != .isolated && isolatedParameter == nil ? "nonisolated(nonsending) " : ""
        return "\(execution)\(closureAttributes)\(input)\(effects.isEmpty ? "" : " \(effects)") -> \(output)"
    }

    /// - Parameters:
    ///   - member: The member's own isolation.
    ///   - container: The mocked type's isolation.
    ///   - isContainerSendable: Whether the mocked type is `Sendable`.
    ///   - actorMockName: The mock's name when the mocked type is an `Actor` protocol.
    init(member: Isolation?, container: Isolation?, isContainerSendable: Bool, actorMockName: String?) {
        let effective: Isolation? = switch member {
        case .globalActor:
            member
        case .nonisolated:
            nil
        case nil:
            container
        }

        isolatedParameter = if let actorMockName, member == nil { "isolated \(actorMockName)" } else { nil }

        if case .globalActor(let name) = effective {
            closureAttributes = "@\(name) @Sendable "
            sharing = .isolated
        } else if isContainerSendable || actorMockName != nil {
            closureAttributes = "@Sendable "
            sharing = .shared
        } else {
            closureAttributes = ""
            sharing = .confined
        }
    }
}

extension Token {
    /// The mock's type as its own members name it: `MockX`, with the generic arguments of a generic mock.
    var mockTypeName: String? {
        (self as? any HasName).map { $0.mockName + ((self as? any HasGenerics)?.genericArgumentsString ?? "") }
    }

    /// The global actor a mocked type is isolated to.
    var declaredIsolation: Isolation? {
        (self as? ProtocolDeclaration)?.isolation ?? (self as? ClassDeclaration)?.isolation
    }

    /// Whether a mocked type states `Sendable` itself. A conformance inherited from elsewhere isn't seen,
    /// so such a mock's stubs fall back to ``StubIsolation/Sharing/confined``, which still compiles.
    var isDeclaredSendable: Bool {
        let inheritedTypes = (self as? ProtocolDeclaration)?.inheritedTypes ?? (self as? ClassDeclaration)?.inheritedTypes ?? []
        return inheritedTypes.contains { $0 == "Sendable" || $0 == "Swift.Sendable" }
    }

    func stubIsolation(forMember isolation: Isolation?) -> StubIsolation {
        let actorMockName = (self as? ProtocolDeclaration).flatMap { $0.isActor ? $0.mockName : nil }
        return StubIsolation(member: isolation, container: declaredIsolation, isContainerSendable: isDeclaredSendable, actorMockName: actorMockName)
    }
}
