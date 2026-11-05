# The Cuckoofile

Tell the generator which files to read, which types to mock and what to import, in `Cuckoofile.toml`.

## Overview

`Cuckoofile.toml` sits at the root of the package or Xcode project, where the build plugins look for it. It holds
one table per module of mocks, `[modules.<Name>]`, and an optional top-level `output`:

```toml
# The file a module without its own `output` writes to. The build plugins pick the output themselves.
output = "Tests/Generated/GeneratedMocks.swift"

[modules.App]
imports = ["Foundation"]
testableImports = ["App"]
sources = ["Sources/App/**/*.swift"]
exclude = ["AppDelegate"]

[modules.App.options]
keepDocumentation = false
defaultIsolation = "MainActor"
```

The name of a module matters with the build plugins. `CuckooPluginModular` generates one file per dependency of
the test target, from the entry with that dependency's name, plus one from the entry named after the test target.
A dependency without an entry gets an empty file. `CuckooPluginSingleFile` generates every entry into one file.

### Sources

- term `sources`: The files to read, relative to the Cuckoofile. `*` matches within a folder, `**` matches any
  number of folders, and `{A,B}` matches either name:

  ```toml
  [modules.App]
  sources = ["Sources/App/**/*.swift", "Sources/Shared/{Clock,Store}.swift"]
  ```

  Or a table of them by the Swift module the files belong to. The mocks then refer to each type by its module,
  so a type that another import also declares, such as SwiftUI's `Namespace`, isn't ambiguous in them:

  ```toml
  [modules.AppAndCore]
  sources = { App = ["Sources/App/**/*.swift"], Core = ["Sources/Core/**/*.swift"] }
  ```

  With a build plugin, leave `sources` out to mock the files of the test target's dependency that has the
  entry's name, or of every dependency if none has it. The plugin lists the target's own files, so this follows
  the target's membership, Xcode's synchronized folders included, and tells the generator which module the files
  belong to, as the table form does.
- term `exclude`: Names of types not to mock, such as `["AppDelegate", "LegacyService"]`.
- term `regex`: Mock only the protocols and classes whose name matches one of these regular expressions:
  `regex = ["Service$", "^Repository"]`. A single pattern needs no array: `regex = "Service$"`.

Cuckoo 2's `xcodeproj` table, which read a target's files from the project, is gone. A Cuckoofile that still has
one fails with a message that says which `sources` to write instead. Replace it with globs that cover the
target's folders:

```toml
# Cuckoo 2
[modules.MyApp]
output = "MyAppTests/GeneratedMocks.swift"
testableImports = ["MyApp"]

[modules.MyApp.xcodeproj]
target = "MyApp"
```

```toml
# Cuckoo 3
[modules.MyApp]
output = "MyAppTests/GeneratedMocks.swift"
testableImports = ["MyApp"]
sources = ["MyApp/**/*.swift", "Shared/**/*.swift"]
```

Globs select files by folder, not by target membership. If a folder also holds files the target doesn't compile,
narrow the glob or list those types in `exclude`. With a build plugin, leave `sources` out instead, to mock the
files of the target.

### Imports

- term `imports`: Modules the generated file imports, such as `["Foundation"]`.
- term `publicImports`: Modules imported with `public import`, for mocks whose public API uses their types.
  Imports are internal by default in Swift 6.
- term `testableImports`: Modules imported with `@testable import`, which mocks of internal types need. If the
  mocked declarations use `@_spi(Group)`, these imports get the same groups, since a testable import doesn't make
  SPI visible.

The generated file always imports `Cuckoo`.

### Output

- term `output`: Where to write the module's mocks. A path with a file extension is one file; modules with the
  same `output` are joined into it. An existing directory, or a path with no extension, gets one file per source
  file. The build plugins replace `output` with a file in the build directory.
- term `filenameFormat`: For a directory `output`, the name of each file, with `{}` where the source file's name
  goes, such as `"{}Mocks"`. It must contain `{}`.

### Options

The `[modules.<Name>.options]` table:

- term `glob`: Whether `sources` are globs, `true` by default. Set it to `false` to read the paths as they are.
- term `keepDocumentation`: Whether mocks keep the mocked declarations' doc comments, `true` by default. Other
  comments are always left out.
- term `enableInheritance`: Whether a mock also overrides the members its type inherits from the other protocols
  and classes in `sources`, `true` by default.
- term `protocolsOnly`: Mock protocols only, not classes. `false` by default.
- term `omitHeaders`: Leave out the comment at the top of each source file's mocks, which names the file. `false`
  by default.
- term `mockPrefix`, `mockSuffix`: Mocks are named `<mockPrefix><Type><mockSuffix>`, `MockGreeter` by default
  (`"Mock"` and `""`). Each may hold letters, digits and underscores; they can't both be empty, and the prefix
  can't start with a digit. `mockSuffix = "Stub"` with no prefix is refused, because the generated
  `<Type>Stub` classes already have those names.
- term `defaultIsolation`: The module's default actor isolation, `"MainActor"` or `"nonisolated"` (the default).
  The generator can't read build settings, so set this when the module builds with
  `.defaultIsolation(MainActor.self)` in SwiftPM, or Xcode's Default Actor Isolation setting: the mocks of types
  that state no isolation are then `@MainActor`, as the types are.

### Running the generator yourself

The build plugins are the way to run the generator. To run it from the command line, as a pre-build script or
to look at what it writes, build `CuckooGenerator` and pass the Cuckoofile:

```sh
swift run --package-path path/to/Cuckoo CuckooGenerator --configuration Cuckoofile.toml --verbose
```

`--verbose` prints each module's settings as the generator reads them. Each module writes to its `output`, or to the
top-level one.
