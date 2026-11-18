#if canImport(ObjectiveC)
import Foundation

@objc
protocol ObjcProtocol {
    @objc
    optional func optionalMethod()
}

@objc
class ObjcClass: NSObject {
    @objc
    func objcMethod() {}
}

@objcMembers
class ObjcMembersClass {
    func objcMethod() {}
}

// Settable optional requirements: Swift reads them through the protocol as immutable optional values.
@objc
protocol ObjcOptionalProperties {
    @objc
    optional var count: Int { get set }
    @objc
    optional var title: String { get set }
    @objc
    optional subscript(index: Int) -> String { get set }
}

final class ObjcOptionalPropertiesImplementation: NSObject, ObjcOptionalProperties {
    var count = 5
    var names = ["zero", "one"]
    subscript(index: Int) -> String {
        get { names[index] }
        set { names[index] = newValue }
    }
}
#endif

#if canImport(ObjectiveC)
/// A plain `@objc` member an extension declares, which implements a protocol's requirement for a subclass.
class ObjcExtensionGreeterBase: NSObject {}

extension ObjcExtensionGreeterBase {
    @objc func greeting() -> String { "base" }
}

protocol ObjcExtensionGreeting {
    func greeting() -> String
}

class ObjcExtensionGreeter: ObjcExtensionGreeterBase, ObjcExtensionGreeting {}
#endif

#if canImport(ObjectiveC)
/// The members of an `@objc extension`, which are all `@objc`, and a plain `@objc` member implementing a throwing
/// requirement.
class ObjcExtensionRingerBase: NSObject {}

@objc extension ObjcExtensionRingerBase {
    func ring() -> String { "base" }
    func fetch() -> String { "base" }
}

protocol ObjcExtensionRinging {
    func ring() -> String
    func fetch() throws -> String
}

class ObjcExtensionRinger: ObjcExtensionRingerBase, ObjcExtensionRinging {}
#endif
