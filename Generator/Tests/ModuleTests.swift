import Foundation
import Testing
#if canImport(CuckooGenerator)
@testable import CuckooGenerator
#endif

@Suite
struct ModuleTests {
    private func dto(xcodeprojTarget: String??) -> Module.DTO {
        Module.DTO(
            imports: nil,
            publicImports: nil,
            testableImports: nil,
            sources: nil,
            exclude: nil,
            regex: nil,
            output: "Mocks.swift",
            filenameFormat: nil,
            options: nil,
            xcodeproj: xcodeprojTarget.map { Module.DTO.Xcodeproj(target: $0) }
        )
    }

    /// Cuckoo 2's `xcodeproj` table is reported with what to write instead, rather than silently ignored.
    @Test
    func leftoverXcodeprojIsRejected() throws {
        let error = try #require(throws: Module.ModuleInitError.self) {
            try Module(name: "MyApp", output: nil, configurationPath: Path("/project/Cuckoofile.toml"), dto: dto(xcodeprojTarget: "App"))
        }
        let message = String(describing: error)
        #expect(message.contains("The `xcodeproj` option was removed in Cuckoo 3."))
        #expect(message.contains("List module MyApp's files with `sources` instead"))
        #expect(message.contains(#"sources = ["App/**/*.swift"]"#))
        #expect(message.contains("(it read the files of target App)"))
        #expect(!message.contains("plugin"))
    }

    @Test
    func leftoverXcodeprojWithoutTargetIsRejected() throws {
        let error = try #require(throws: Module.ModuleInitError.self) {
            try Module(name: "MyApp", output: nil, configurationPath: Path("/project/Cuckoofile.toml"), dto: dto(xcodeprojTarget: .some(nil)))
        }
        #expect(String(describing: error).contains(#"sources = ["MyApp/**/*.swift"]"#))
    }

    @Test
    func noXcodeproj() throws {
        let module = try Module(name: "MyApp", output: nil, configurationPath: Path("/project/Cuckoofile.toml"), dto: dto(xcodeprojTarget: nil))
        #expect(module.name == "MyApp")
    }
}
