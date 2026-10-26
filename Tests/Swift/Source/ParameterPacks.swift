import Foundation

protocol ParameterPackProtocol {
    func combine<each T>(_ values: repeat each T) -> (repeat each T)
    func count<each T>(_ values: repeat each T) -> Int
    func log<each T>(_ prefix: String, _ values: repeat each T)
    func describe<each T: CustomStringConvertible>(_ values: repeat each T) async throws -> String
}

/// Swift can't override a method with a parameter pack, so a class mock keeps the real implementation.
class ParameterPackClass {
    func name() -> String {
        "real"
    }

    func count<each T>(_ values: repeat each T) -> Int {
        var count = 0
        for _ in repeat each values {
            count += 1
        }
        return count
    }
}
