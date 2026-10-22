enum NetErr: Error { case offline }
protocol TypedAPI {
    func call() throws(NetErr) -> Int
    func callAsync() async throws(NetErr) -> Int
}
