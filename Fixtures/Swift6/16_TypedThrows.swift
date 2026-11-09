enum NetErr: Error { case offline }
enum Network {
    enum Failure: Error { case timeout }
}
struct Wrapped<Value>: Error {}
protocol TypedAPI {
    func call() throws(NetErr) -> Int
    func callAsync() async throws(NetErr) -> Int
    // Error types that aren't a plain name, and a closure parameter with its own typed throws.
    func fetch() throws(Network.Failure) -> String
    func decode() throws(Wrapped<Int>)
    func retry(_ operation: @escaping () throws(NetErr) -> Int) -> Int
    func log(_ write: (String...) -> Void)
}
