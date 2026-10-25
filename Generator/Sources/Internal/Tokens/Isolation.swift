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

    var sharingType: String {
        "Cuckoo.StubSharing.\(sharing.rawValue)"
    }

    /// The `then` closure type for `input` (a tuple type, `Void` for none) and `output`.
    func implementationType(input: String, output: String, isAsync: Bool, throwsClause: String?) -> String {
        let effects = [isAsync ? "async" : nil, throwsClause].compactMap { $0 }.joined(separator: " ")
        // A nonisolated async closure runs on the caller's actor, like the member it stands in for, so
        // the call's non-`Sendable` arguments don't have to cross into the concurrent pool.
        let execution = isAsync && sharing != .isolated ? "nonisolated(nonsending) " : ""
        return "\(execution)\(closureAttributes)(\(input))\(effects.isEmpty ? "" : " \(effects)") -> \(output)"
    }

    /// - Parameters:
    ///   - member: The member's own isolation.
    ///   - container: The mocked type's isolation.
    ///   - isContainerSendable: Whether the mocked type is `Sendable`.
    init(member: Isolation?, container: Isolation?, isContainerSendable: Bool) {
        let effective: Isolation? = switch member {
        case .globalActor:
            member
        case .nonisolated:
            nil
        case nil:
            container
        }

        if case .globalActor(let name) = effective {
            closureAttributes = "@\(name) @Sendable "
            sharing = .isolated
        } else if isContainerSendable {
            closureAttributes = "@Sendable "
            sharing = .shared
        } else {
            closureAttributes = ""
            sharing = .confined
        }
    }
}

extension Token {
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
        StubIsolation(member: isolation, container: declaredIsolation, isContainerSendable: isDeclaredSendable)
    }
}
