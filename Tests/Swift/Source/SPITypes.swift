/// A value only clients that import the module with `@_spi(CuckooTests)` see.
@_spi(CuckooTests) public struct AccessToken: Equatable, Sendable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

/// A public protocol with an SPI requirement. Its mock lives in another module, which the generated file imports
/// with `@_spi(CuckooTests)`.
public protocol Vault {
    func isOpen() -> Bool
    @_spi(CuckooTests) func unlock(with token: AccessToken) -> Bool
}

extension Vault {
    @_spi(CuckooTests) public func unlock(with token: AccessToken) -> Bool {
        false
    }
}
