// Properties with only reading accessors, `_read` among them, are read-only; one with observers is settable.
class Library {
    init() {}
    private var storage = ["a"]
    var titles: [String] {
        _read { yield storage }
    }
    var count: Int {
        get { storage.count }
    }
    var name = "" {
        didSet {}
    }
}
