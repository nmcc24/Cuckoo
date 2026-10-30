import Foundation

/// Foundation declares a `Unit` too, and the mocks import Foundation. Without a scoped import of this one, the name
/// is ambiguous in every mock of the module.
struct Unit: Equatable {
    let symbol: String
}

/// A type named like its module, `CuckooTestSources.CuckooTestSources`. The mocks' scoped imports still name the module.
struct CuckooTestSources: Equatable {
    let id: Int
}

protocol UnitConverter {
    func convert(_ value: Double, to unit: Unit) -> Double
    func describe(_ sources: CuckooTestSources) -> String
}
