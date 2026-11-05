# Cookbook

Recipes for common test setups in Swift 6 code.

## Overview

Each recipe shows the code under test, then a test with its mock. The mocks are generated from the protocols
shown, as <doc:GettingStarted> sets up.

### Test a MainActor view model

A view model and the service it calls are often `@MainActor`. The service's mock is `@MainActor` too, so the test
runs on the main actor, and the stub's closures can use main-actor state directly:

```swift
@MainActor
protocol ProfileService {
    func profile(id: Int) async throws -> Profile
}

@MainActor @Observable
final class ProfileViewModel {
    private let service: any ProfileService
    private(set) var name = ""

    init(service: any ProfileService) {
        self.service = service
    }

    func load(id: Int) async {
        name = (try? await service.profile(id: id).name) ?? "Unknown"
    }
}
```

```swift
@Test @MainActor
func showsTheProfileName() async {
    let service = MockProfileService()
    stub(service) { stub in
        when(stub.profile(id: 7)).thenReturn(Profile(name: "Ann"))
    }
    let viewModel = ProfileViewModel(service: service)

    await viewModel.load(id: 7)

    #expect(viewModel.name == "Ann")
    verify(service).profile(id: 7)
}
```

A `@MainActor` mock's `thenReturn` takes any value, `Sendable` or not, because it's sent to the main actor where
every call runs.

### Wait for work the code under test starts

When the code starts a `Task` and returns, the test can't await the call it makes. Wrap the `verify` in
``eventually(timeout:pollingInterval:_:)``, which retries it until it passes or the timeout runs out:

```swift
@Test @MainActor
func refreshesInTheBackground() async {
    let service = MockFeedService()
    stub(service) { stub in
        when(stub.refresh()).thenDoNothing()
    }
    let viewModel = FeedViewModel(service: service)

    viewModel.pullToRefresh() // starts a Task and returns

    await eventually {
        verify(service).refresh()
    }
}
```

`eventually` waits for something to become true. To check that a call never happens, let the work finish first,
then `verify(service, never())` outside it.

### Mock an actor

The mock of an `actor` protocol is an actor, so its members are called with `await` from outside, as the real
actor's are. Its `then` closures run on the mock and receive it, `isolated`, before the call's arguments:

```swift
protocol TokenStore: Actor {
    func token(for user: String) -> String?
    func save(_ token: String, for user: String)
}
```

```swift
@Test
func savesTheRefreshedToken() async {
    let store = MockTokenStore()
    stub(store) { stub in
        when(stub.token(for: any())).thenReturn(nil)
        when(stub.save(any(), for: any())).then { _, token, user in
            print("saved \(token) for \(user)")
        }
    }

    await Session(store: store).refresh(user: "ann")

    verify(store).save(any(), for: "ann")
}
```

Actor mocks have no default implementation: forwarding a call's arguments to another actor would race. Stub every
member the test reaches.

### Share mocks across a Swift Testing suite

Swift Testing creates a new suite instance for each test, so mocks stored in a suite's properties are fresh in
every test. Put the shared stubbing in `init`, and settings for every test on the suite with `.cuckoo()`:

```swift
@Suite(.cuckoo())
struct CheckoutTests {
    let payments = MockPaymentService()
    let checkout: Checkout

    init() {
        stub(payments) { stub in
            when(stub.authorize(amount: any())).thenReturn(.approved)
        }
        checkout = Checkout(payments: payments)
    }

    @Test func chargesTheTotal() async throws {
        try await checkout.pay(total: 20)
        verify(payments).authorize(amount: 20)
    }

    @Test func declinesOverTheLimit() async throws {
        stub(payments) { stub in
            when(stub.authorize(amount: 1_000)).thenReturn(.declined) // newer stubs win
        }
        await #expect(throws: CheckoutError.declined) {
            try await checkout.pay(total: 1_000)
        }
    }
}
```

Tests in a suite run in parallel, and each has its own mocks, so they don't see each other's stubs or calls.
Static members' stubs need the `.cuckoo()` trait for the same reason, as <doc:StubbingAndVerification> explains.

### Simulate a slow or hanging call

A `then` closure can do anything the member can, so it can wait before it answers, or never answer:

```swift
stub(service) { stub in
    when(stub.profile(id: 1)).then { _ in
        try await Task.sleep(for: .milliseconds(200))
        return Profile(name: "Slow")
    }
    when(stub.profile(id: 2)).then { _ in
        try await Task.sleep(for: .seconds(3_600)) // ends only when the task is cancelled
        return Profile(name: "Never")
    }
}
```

Use the hanging one to test a timeout or a cancel button; cancelling the caller's task ends the sleep with
`CancellationError`.

### Mock an Objective-C dependency

Cuckoo mocks Swift declarations only. Put a small Swift protocol in front of the Objective-C type, conform the type
to it in an extension, and depend on the protocol:

```swift
protocol Analytics {
    func track(_ event: String, properties: [String: String])
}

extension LegacyAnalyticsClient: Analytics {}
```

The code under test takes an `any Analytics`, the app passes `LegacyAnalyticsClient.shared`, and tests pass a
`MockAnalytics`.

### Capture a completion handler

To drive a callback-based API, capture the closure with an ``ArgumentCaptor`` and call it yourself:

```swift
protocol Downloader {
    func download(_ url: URL, completion: @escaping (Result<Data, any Error>) -> Void)
}
```

```swift
@Test
func showsTheDownloadedImage() {
    let downloader = MockDownloader()
    stub(downloader) { stub in
        when(stub.download(any(), completion: any())).thenDoNothing()
    }
    let viewer = ImageViewer(downloader: downloader)
    viewer.open(URL(string: "https://example.com/a.png")!)

    let completion = ArgumentCaptor<(Result<Data, any Error>) -> Void>()
    verify(downloader).download(any(), completion: completion.capture())
    completion.value?(.success(Data([0x89])))

    #expect(viewer.hasImage)
}
```

Or answer from the stub, with `then { _, completion in completion(.success(data)) }`.
