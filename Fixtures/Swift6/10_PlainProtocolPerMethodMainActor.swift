protocol Analytics {
    @MainActor func track(event: String)
    @MainActor var lastEvent: String? { get }
}
