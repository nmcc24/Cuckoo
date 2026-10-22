@globalActor
actor DatabaseActor { static let shared = DatabaseActor() }

@DatabaseActor
protocol Repository {
    func save(_ value: String)
    func all() -> [String]
}
