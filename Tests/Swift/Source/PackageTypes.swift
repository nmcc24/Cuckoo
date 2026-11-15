// `package` declarations, which a mock in another module of the same package can see and override.
package protocol PackageService {
    func run(_ value: Int) -> Int
}

package class PackageWorker {
    package init() {}

    package func work() -> String {
        "real"
    }
}
