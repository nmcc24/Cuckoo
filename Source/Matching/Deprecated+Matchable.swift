/// Cuckoo 2's name for the protocol that generated mocks take their arguments' matchers through.
///
/// Don't conform your own types to it: pass `equal(to:)`, which takes any `Equatable` value. A conformance of a
/// type you don't own also needs `@retroactive`. Cuckoo 4 hides this protocol from your code.
@available(*, deprecated, message: "Pass equal(to:) instead of conforming your own types to Matchable.")
public typealias Matchable = _Matchable

/// Cuckoo 2's name for the protocol that generated mocks take their optional arguments' matchers through.
///
/// Don't conform your own types to it: pass `equal(to:)`, which takes any `Equatable` value. Cuckoo 4 hides this
/// protocol from your code.
@available(*, deprecated, message: "Pass equal(to:) instead of conforming your own types to OptionalMatchable.")
public typealias OptionalMatchable = _OptionalMatchable
