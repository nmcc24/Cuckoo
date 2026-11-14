import Cuckoo

// Must not compile: a main-actor mock's verification proxy is main-actor isolated, so a test that isn't on the main
// actor can't read the mock's recorded arguments while the main actor may still change them. Listed in the expected
// failures.
nonisolated final class Page {
    var lines: [String] = []
}

@MainActor
protocol PageRenderer {
    func render(_ page: Page)
}

nonisolated func verifyRendering(renderer: MockPageRenderer) async {
    await eventually {
        verify(renderer).render(ParameterMatcher { $0.lines.count > 3 })
    }
}
