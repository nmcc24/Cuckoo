/// Names the generated code declares, which several builders and tokens spell.
enum GeneratedNames {
    /// The generic parameter of `enableDefaultImplementation(_:)` on a generic protocol's mock, which stands for the
    /// default implementation's type.
    static let staticGenericParameter = "_CUCKOO$$GENERIC"
    /// The type-erasing caller a generic protocol's mock calls its default implementation through.
    static let typeErasureClassName = "__DefaultImplCaller"
    /// What starts the name of a mock's typealias of one of its protocol's typealiases, `__CuckooSelf_Key` of `Key`,
    /// for the members whose own generic parameter `Key` shadows it.
    static let selfTypealiasPrefix = "__CuckooSelf_"
}
