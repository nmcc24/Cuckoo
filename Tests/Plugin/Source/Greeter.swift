/// Mocked through the module's `Cuckoofile.toml` entry, which lists no `sources`: the build plugin passes the
/// target's files with `--sources-list`.
protocol Greeter {
    func greet(_ name: String) -> String
}
