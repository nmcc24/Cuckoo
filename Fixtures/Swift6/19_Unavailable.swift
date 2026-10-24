import Foundation

// A non-@objc protocol can't declare a member unavailable on the platform being compiled,
// so the protocol only names platforms the matrix never compiles for (it runs on macOS and Linux).
protocol Legacy {
    @available(iOS, unavailable)
    func notOnIOS()
    @available(tvOS, unavailable, message: "not on tvOS")
    func notOnTVOS()
    @available(macCatalyst, unavailable)
    func notOnCatalyst()
    @available(iOSApplicationExtension, unavailable)
    func notInExtensions()
    @available(*, deprecated, message: "use kept()")
    func deprecated()
    func kept()
}

class LegacyService {
    @available(*, unavailable)
    func gone() {}
    @available(*, unavailable, message: "use kept()")
    var removed: Int { 0 }
    @available(macOS, unavailable, message: "not on macOS")
    func notOnMacOS() {}
    func kept() {}
}

class LegacyView {
    init(frame: Int) {}
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    func kept() {}
}
