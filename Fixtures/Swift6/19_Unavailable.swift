import Foundation

protocol Legacy {
    @available(iOS, unavailable)
    func notOnIOS()
    @available(macOS, unavailable, message: "not on macOS")
    func notOnMacOS()
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
    func kept() {}
}

class LegacyView {
    init(frame: Int) {}
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    func kept() {}
}
