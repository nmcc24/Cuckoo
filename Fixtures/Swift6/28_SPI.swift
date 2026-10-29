@_spi(Internal) public struct Token {
    public init() {}
}

public protocol Service {
    func open()
    @_spi(Internal) func secret(_ token: Token) -> Token
    @_spi(Internal) var token: Token { get set }
}

extension Service {
    @_spi(Internal) public func secret(_ token: Token) -> Token { token }
    @_spi(Internal) public var token: Token {
        get { Token() }
        set {}
    }
}

@_spi(Admin) public protocol AdminService {
    func reset(_ token: Token)
}

public protocol Repository {
    associatedtype Item
    func fetch() -> Item?
    @_spi(Internal) func secret(_ token: Token)
}

extension Repository {
    @_spi(Internal) public func secret(_ token: Token) {}
}

open class Session {
    public init() {}
    open func start() {}
    @_spi(Internal) open func resume(with token: Token) {}
    @_spi(Internal) public init(token: Token) {}
}

@_spi(Admin) public enum Admin {
    open class Console {
        public init() {}
        open func run(_ token: Token) {}
    }
}
