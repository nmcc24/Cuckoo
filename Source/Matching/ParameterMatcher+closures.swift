// MARK: - Closures.
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<OUT>() -> SendableMatcher<() -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<(IN1) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<(IN1, IN2) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(IN1, IN2, IN3) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6, IN7) -> OUT> { SendableMatcher() }


// MARK: - Throwing closures.
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<OUT>() -> SendableMatcher<() throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, OUT>() -> SendableMatcher<(IN1) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, IN2, OUT>() -> SendableMatcher<(IN1, IN2) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(IN1, IN2, IN3) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6, IN7) throws -> OUT> { SendableMatcher() }


// MARK: - Async closures.
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<OUT>() -> SendableMatcher<() async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<(IN1) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<(IN1, IN2) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(IN1, IN2, IN3) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6, IN7) async -> OUT> { SendableMatcher() }


// MARK: - Async throwing closures.
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<OUT>() -> SendableMatcher<() async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, OUT>() -> SendableMatcher<(IN1) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, IN2, OUT>() -> SendableMatcher<(IN1, IN2) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(IN1, IN2, IN3) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(IN1, IN2, IN3, IN4, IN5, IN6, IN7) async throws -> OUT> { SendableMatcher() }


// MARK: - Sendable closures.
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<OUT>() -> SendableMatcher<@Sendable () -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<@Sendable (IN1) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<@Sendable (IN1, IN2) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6) -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6, IN7) -> OUT> { SendableMatcher() }


// MARK: - Sendable throwing closures.
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<OUT>() -> SendableMatcher<@Sendable () throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, OUT>() -> SendableMatcher<@Sendable (IN1) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, IN2, OUT>() -> SendableMatcher<@Sendable (IN1, IN2) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6) throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6, IN7) throws -> OUT> { SendableMatcher() }


// MARK: - Sendable async closures.
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<OUT>() -> SendableMatcher<@Sendable () async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<@Sendable (IN1) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<@Sendable (IN1, IN2) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6) async -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async non-throwing closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6, IN7) async -> OUT> { SendableMatcher() }


// MARK: - Sendable async throwing closures.
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<OUT>() -> SendableMatcher<@Sendable () async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, OUT>() -> SendableMatcher<@Sendable (IN1) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, IN2, OUT>() -> SendableMatcher<@Sendable (IN1, IN2) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6) async throws -> OUT> { SendableMatcher() }
/// Returns a matcher matching any @Sendable async throwing closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<@Sendable (IN1, IN2, IN3, IN4, IN5, IN6, IN7) async throws -> OUT> { SendableMatcher() }


// MARK: - Optional closures.
/// Returns a matcher matching any optional closure.
public func anyClosure<OUT>() -> SendableMatcher<(() -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<(((IN1)) -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<(((IN1, IN2)) -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(((IN1, IN2, IN3)) -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4)) -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5)) -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5, IN6)) -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5, IN6, IN7)) -> OUT)?> { notNil() }


// MARK: - Optional async closures.
/// Returns a matcher matching any optional closure.
public func anyClosure<OUT>() -> SendableMatcher<(() async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<(((IN1)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<(((IN1, IN2)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(((IN1, IN2, IN3)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5, IN6)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5, IN6, IN7)) async -> OUT)?> { notNil() }


// MARK: - Optional async throwing closures.
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<OUT>() -> SendableMatcher<(() async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, OUT>() -> SendableMatcher<(((IN1)) async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, IN2, OUT>() -> SendableMatcher<(((IN1, IN2)) async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(((IN1, IN2, IN3)) async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4)) async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5)) async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5, IN6)) async throws -> OUT)?> { notNil() }
/// Returns a matcher matching any optional closure.
public func anyThrowingClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(((IN1, IN2, IN3, IN4, IN5, IN6, IN7)) async throws -> OUT)?> { notNil() }


// MARK: - Optional sendable closures.
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<OUT>() -> SendableMatcher<(@Sendable () -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<(@Sendable ((IN1)) -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2)) -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3)) -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4)) -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4, IN5)) -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4, IN5, IN6)) -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4, IN5, IN6, IN7)) -> OUT)?> { notNil() }


// MARK: - Optional sendable async closures.
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<OUT>() -> SendableMatcher<(@Sendable () async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, OUT>() -> SendableMatcher<(@Sendable ((IN1)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4, IN5)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4, IN5, IN6)) async -> OUT)?> { notNil() }
/// Returns a matcher matching any @Sendable optional closure.
public func anyClosure<IN1, IN2, IN3, IN4, IN5, IN6, IN7, OUT>() -> SendableMatcher<(@Sendable ((IN1, IN2, IN3, IN4, IN5, IN6, IN7)) async -> OUT)?> { notNil() }
