@MainActor
protocol MainActorService {
    var title: String { get set }
    func load(id: Int) -> String
    func refresh() async throws
}
